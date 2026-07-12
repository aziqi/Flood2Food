import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'ble_service_base.dart';
import '../models/bluetooth_sensor_data.dart';

class RealBleService extends BleServiceBase {
  static const String _serviceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String _txCharUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const String _rxCharUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

  fbp.BluetoothDevice? _connectedDevice;
  fbp.BluetoothCharacteristic? _writeCharacteristic;
  StreamSubscription<List<int>>? _dataSubscription;
  StreamSubscription<fbp.BluetoothConnectionState>? _connSub;
  final _dataController = StreamController<BluetoothSensorData>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  String _jsonBuffer = '';
  String _historyCsvBuffer = '';
  static const int _maxBufferSize = 1048576; // 1MB - RAM HP sangat besar

  String? _lastDeviceId;
  bool _autoReconnect = true;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  @override
  Stream<BluetoothSensorData> get dataStream => _dataController.stream;
  @override
  Stream<bool> get connectionState => _connectionController.stream;
  @override
  bool get isConnected => _connectedDevice?.isConnected ?? false;

  @override
  Stream<List<BleScanResult>> get scanResultsStream => fbp.FlutterBluePlus.scanResults.map((results) {
    return results
        .where((r) {
          final name = r.advertisementData.advName;
          // Filter to only show relevant devices
          return name.isNotEmpty && (name.toLowerCase().contains("flood") || name.toLowerCase().contains("gateway") || name.toLowerCase().contains("node"));
        })
        .map((r) => BleScanResult(
              deviceId: r.device.remoteId.str,
              name: r.advertisementData.advName,
              rssi: r.rssi,
            ))
        .toList();
  });

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      await fbp.FlutterBluePlus.startScan(
        timeout: timeout,
      );
    } catch (e) {
      debugPrint('[BLE] Scan exception: $e');
    }
  }

  @override
  Future<void> stopScan() async {
    await fbp.FlutterBluePlus.stopScan();
  }

  @override
  Future<void> connect(String deviceId) async {
    _lastDeviceId = deviceId;
    _autoReconnect = true;
    _reconnectAttempts = 0;
    await _doConnect(deviceId);
  }

  Future<void> _doConnect(String deviceId) async {
    try {
      final device = fbp.BluetoothDevice.fromId(deviceId);
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));
      _connectedDevice = device;
      _connectionController.add(true);

      try {
        await device.requestMtu(512);
        debugPrint('[BLE] MTU 512 requested successfully');
      } catch (mtuErr) {
        debugPrint('[BLE] Request MTU failed, continuing: $mtuErr');
      }

      _connSub = device.connectionState.listen((state) {
        if (state == fbp.BluetoothConnectionState.disconnected && _autoReconnect) {
          _connectionController.add(false);
          // 🔥 DEEP OPTIMIZATION: Mencegah Buffer Overflow akibat putus di tengah jalan!
          _historyCsvBuffer = ''; 
          _jsonBuffer = '';
          _writeCharacteristic = null; // FIX: Bersihkan koneksi basi
          _scheduleReconnect();
        }
      });

      final svcs = await device.discoverServices();
      await _subscribeToDataCharacteristic(svcs);
      
      // 🔥 DEEP OPTIMIZATION: Tembakkan jam HP ke Node begitu koneksi berhasil!
      // Node akan menerima Unix Epoch dan menggunakannya sebagai Virtual RTC.
      await _syncTimeToNode();
      
      // 🔥 DEEP OPTIMIZATION: Minta History SD Card secara otomatis setelah jam disinkronkan!
      // Sebelumnya Node dilarang mengirim otomatis agar HP tidak tersedak, 
      // sekarang HP yang proaktif meminta "H" ke Node.
      debugPrint('[BLE] Meminta History dari SD Card...');
      await sendCommand("H");
      
    } catch (e) {
      _connectionController.add(false);
      rethrow;
    }
  }

  Future<void> _syncTimeToNode() async {
    if (_writeCharacteristic == null) return;
    try {
      final now = DateTime.now();
      // 🔥 FIX TIMEZONE: Tambahkan offset lokal (misal WIB +7 jam) agar Node 
      // yang tidak punya library zona waktu bisa menampilkan jam dengan benar!
      final offsetSeconds = now.timeZoneOffset.inSeconds;
      final localEpoch = (now.millisecondsSinceEpoch ~/ 1000) + offsetSeconds;
      
      // Format ringkas: TIME:UnixEpoch (Hanya 15-18 bytes, aman dari batas MTU 20 byte)
      final msg = "TIME:$localEpoch";
      await _writeCharacteristic!.write(utf8.encode(msg), withoutResponse: false);
      debugPrint('[BLE] Waktu HP berhasil ditembakkan ke Node: $msg');
    } catch (e) {
      debugPrint('[BLE] Gagal mengirim waktu ke Node: $e');
    }
  }

  Future<void> _subscribeToDataCharacteristic(
    List<fbp.BluetoothService> services,
  ) async {
    debugPrint('[BLE] Discovering characteristics for subscription...');
    _writeCharacteristic = null; // FIX: Selalu reset characteristic tiap kali terhubung ulang!
    for (final svc in services) {
      debugPrint('[BLE] Service: ${svc.uuid.str}');
      for (final chr in svc.characteristics) {
        debugPrint('[BLE]   Char: ${chr.uuid.str}, Properties: notify=${chr.properties.notify}, read=${chr.properties.read}, write=${chr.properties.write}');
      }
    }

    try {
      bool foundTx = false;
      for (final svc in services) {
        if (svc.uuid.str.toLowerCase() == _serviceUuid) {
          for (final chr in svc.characteristics) {
            if (chr.uuid.str.toLowerCase() == _txCharUuid) {
              debugPrint('[BLE] Found matching Service and TX Characteristic. Subscribing...');
              if (chr.properties.notify || chr.properties.indicate) {
                await chr.setNotifyValue(true);
                debugPrint('[BLE] Notifications enabled on matching TX Char');
              } else {
                debugPrint('[BLE] Warning: Matching TX Char does not support notify/indicate!');
              }
              _dataSubscription = chr.onValueReceived.listen((data) {
                // debugPrint('[BLE_STREAM] onValueReceived fired'); // Dimatikan agar log tidak membanjiri RAM
                _handleRawData(data);
              });
              // 🔥 DEEP OPTIMIZATION: Membuang chr.lastValueStream.listen yang tidak pernah di-cancel
              // dan berpotensi menjadi Zombie Memory Leak jika terhubung berkali-kali.
              _connectedDevice!.cancelWhenDisconnected(_dataSubscription!);
              foundTx = true;
            } else if (chr.uuid.str.toLowerCase() == _rxCharUuid) {
              debugPrint('[BLE] Found matching Service and RX Characteristic for writing.');
              _writeCharacteristic = chr;
            }
          }
        }
      }

      if (foundTx) return;

      // Fallback: subscribe to the first notify-capable characteristic
      bool foundNotify = false;
      for (final svc in services) {
        for (final chr in svc.characteristics) {
          if ((chr.properties.write || chr.properties.writeWithoutResponse) && _writeCharacteristic == null) {
            _writeCharacteristic = chr;
            debugPrint('[BLE] Fallback: Found writable characteristic: ${chr.uuid.str}');
          }
          if ((chr.properties.notify || chr.properties.indicate) && !foundNotify) {
            debugPrint('[BLE] Fallback: Subscribing to first notify char: ${chr.uuid.str}');
            await chr.setNotifyValue(true);
            debugPrint('[BLE] Notifications enabled on fallback Char');
            _dataSubscription = chr.onValueReceived.listen((data) {
              debugPrint('[BLE_STREAM] fallback onValueReceived fired');
              _handleRawData(data);
            });
            chr.lastValueStream.listen((data) {
              if (data.isNotEmpty) {
                debugPrint('[BLE_STREAM] fallback lastValueStream fired');
                _handleRawData(data);
              }
            });
            _connectedDevice!.cancelWhenDisconnected(_dataSubscription!);
            foundNotify = true;
          }
        }
      }
      if (foundNotify) return;
      debugPrint('[BLE] Error: No notify-capable characteristic found!');
    } catch (subscribeErr) {
      debugPrint('[BLE] FATAL Error during subscription: $subscribeErr');
      rethrow;
    }
  }

  void _handleRawData(List<int> bytes) {
    debugPrint('[BLE_RAW] === Received ${bytes.length} bytes ===');
    try {
      final chunk = utf8.decode(bytes, allowMalformed: true);
      debugPrint('[BLE_RAW] Decoded: ${chunk.length} chars, first 80: ${chunk.substring(0, chunk.length > 80 ? 80 : chunk.length)}');
      _jsonBuffer += chunk;

      if (_jsonBuffer.length > _maxBufferSize) {
        debugPrint('[BLE_DATA] Buffer overflow at ${_jsonBuffer.length}, clearing');
        _jsonBuffer = '';
        return;
      }

      // Extract all complete JSON objects from buffer
      while (_jsonBuffer.isNotEmpty) {
        final startIdx = _jsonBuffer.indexOf('{');
        if (startIdx == -1) {
          debugPrint('[BLE_DATA] No JSON found in buffer, clearing');
          _jsonBuffer = '';
          break;
        }

        // Find matching closing brace
        int depth = 0;
        int endIdx = -1;
        for (int i = startIdx; i < _jsonBuffer.length; i++) {
          if (_jsonBuffer[i] == '{') depth++;
          if (_jsonBuffer[i] == '}') depth--;
          if (depth == 0) {
            endIdx = i;
            break;
          }
        }

        if (endIdx == -1) {
          debugPrint('[BLE_DATA] Incomplete JSON, waiting for more data. Buffer: ${_jsonBuffer.length} bytes');
          break;
        }

        final jsonStr = _jsonBuffer.substring(startIdx, endIdx + 1);
        _jsonBuffer = _jsonBuffer.substring(endIdx + 1);
        debugPrint('[BLE_DATA] Extracted JSON (${jsonStr.length} chars): ${jsonStr.substring(0, jsonStr.length > 100 ? 100 : jsonStr.length)}...');

        try {
          final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (jsonMap['type'] == 'chunk') {
            _historyCsvBuffer += jsonMap['data'];
            debugPrint('[BLE_DATA] Chunk received, buffer now: ${_historyCsvBuffer.length} bytes');
            
            final int chunkIdx = jsonMap['idx'] ?? 0;
            final int chunkTotal = jsonMap['total'] ?? 1;
            
            final progressData = BluetoothSensorData.fromJson({
              'node_id': _lastDeviceId ?? 'SYSTEM',
              'status': 'sync_progress',
              'temperature': chunkIdx + 1,
              'humidity': chunkTotal,
            });
            if (!_dataController.isClosed) _dataController.add(progressData);
            
            continue;
          } else if (jsonMap['type'] == 'history_complete') {
            debugPrint('[BLE_DATA] History Complete. Processing ${_historyCsvBuffer.length} bytes of CSV...');
            _processHistoryCsvBuffer();
            _historyCsvBuffer = '';
            
            final completeData = BluetoothSensorData.fromJson({
              'node_id': 'SYSTEM',
              'status': 'history_complete',
            });
            if (!_dataController.isClosed) _dataController.add(completeData);
            continue;
          }
        } catch (e) {
          debugPrint('[BLE_DATA] Inner JSON parse note: $e');
        }

        final data = _parseSensorData(jsonStr);
        if (data != null) {
          if (data.status != 'history_complete') {
            debugPrint('[BLE_DATA] Parsed Live Data: N=${data.n} P=${data.p} K=${data.k} EC=${data.kond}');
          }
          if (!_dataController.isClosed) {
            _dataController.add(data);
          }
        } else {
          debugPrint('[BLE_DATA] _parseSensorData returned NULL for: ${jsonStr.substring(0, jsonStr.length > 120 ? 120 : jsonStr.length)}');
        }
      }
    } catch (e) {
      debugPrint('[BLE_DATA] FATAL Error in _handleRawData: $e');
      _jsonBuffer = '';
    }
  }

  BluetoothSensorData? _parseSensorData(String str) {
    try {
      str = str.trim();
      if (str.isEmpty) return null;

      final startIdx = str.indexOf('{');
      final endIdx = str.lastIndexOf('}');
      if (startIdx == -1 || endIdx == -1 || endIdx <= startIdx) return null;

      str = str.substring(startIdx, endIdx + 1);
      final json = jsonDecode(str) as Map<String, dynamic>;

      if (!json.containsKey('node_id') && !json.containsKey('type')) {
        return null;
      }
      
      if (json.containsKey('status') && json['status'] == 'disconnected') return null;

      return BluetoothSensorData.fromJson(json);
    } catch (e) {
      debugPrint('[BLE_PARSE] Error parsing: $e, input: $str');
      return null;
    }
  }

  void _processHistoryCsvBuffer() {
    try {
      _historyCsvBuffer = _historyCsvBuffer.replaceAll('|', '\n');
      int lineStart = 0;
      while (lineStart < _historyCsvBuffer.length) {
        int lineEnd = _historyCsvBuffer.indexOf('\n', lineStart);
        if (lineEnd == -1) lineEnd = _historyCsvBuffer.length;
        String csvLine = _historyCsvBuffer.substring(lineStart, lineEnd).trim();
        lineStart = lineEnd + 1;
        
        if (csvLine.isEmpty) continue;
        if (csvLine.startsWith('Waktu') || csvLine.startsWith('waktu')) continue;

        List<int> commaIdx = [];
        for (int i = 0; i < csvLine.length; i++) {
          if (csvLine[i] == ',') commaIdx.add(i);
        }
        
        if (commaIdx.length < 8) continue;

        String wkt = csvLine.substring(0, commaIdx[0]);
        String tgl = csvLine.substring(commaIdx[0]+1, commaIdx[1]);
        double suhu = double.tryParse(csvLine.substring(commaIdx[1]+1, commaIdx[2])) ?? 0;
        double humi = double.tryParse(csvLine.substring(commaIdx[2]+1, commaIdx[3])) ?? 0;
        double kond = double.tryParse(csvLine.substring(commaIdx[3]+1, commaIdx[4])) ?? 0;
        double ph   = double.tryParse(csvLine.substring(commaIdx[4]+1, commaIdx[5])) ?? 0;
        double n    = double.tryParse(csvLine.substring(commaIdx[5]+1, commaIdx[6])) ?? 0;
        double p    = double.tryParse(csvLine.substring(commaIdx[6]+1, commaIdx[7])) ?? 0;
        
        double k = 0;
        if (commaIdx.length > 8) {
          k = double.tryParse(csvLine.substring(commaIdx[7]+1, commaIdx[8])) ?? 0;
        } else {
          k = double.tryParse(csvLine.substring(commaIdx[7]+1)) ?? 0;
        }

        try {
          final partsTgl = tgl.split('/');
          final partsWkt = wkt.split(':');
          if (partsTgl.length == 3 && partsWkt.length >= 2) {
            String tsStr = '${partsTgl[2]}-${partsTgl[1].padLeft(2, '0')}-${partsTgl[0].padLeft(2, '0')}T${partsWkt[0].padLeft(2, '0')}:${partsWkt[1].padLeft(2, '0')}:${partsWkt.length > 2 ? partsWkt[2].padLeft(2, '0') : '00'}';
            
            final data = BluetoothSensorData.fromJson({
              'node_id': _lastDeviceId ?? 'N01',
              'timestamp': tsStr,
              'temperature': suhu,
              'humidity': humi,
              'ec': kond / 1000.0, // Because in app it gets multiplied by 1000 later? Wait, the Gateway sent kond/1000.0 in JSON. My flutter fix expects Gateway format!
              'ph': ph,
              'nitrogen': n,
              'phosphorus': p,
              'kalium': k,
              'status': 'history'
            });
            
            if (!_dataController.isClosed) {
              _dataController.add(data);
            }
          }
        } catch (e) {
          debugPrint('[BLE_PARSE] Failed parsing CSV line date: $e');
        }
      }
    } catch (e) {
      debugPrint('[BLE_PARSE] Error processing CSV buffer: $e');
    }
  }

  void _scheduleReconnect() {
    if (!_autoReconnect || _lastDeviceId == null) return;
    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    if (_reconnectAttempts > 5) return;

    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _doConnect(_lastDeviceId!).then((_) {
        _reconnectAttempts = 0;
      }).catchError((e) {
        _scheduleReconnect();
      });
    });
  }

  @override
  Future<void> cancelSync() async {
    if (_writeCharacteristic != null) {
      try {
        await _writeCharacteristic!.write(utf8.encode("ABORT\n"), withoutResponse: false);
        debugPrint('[BLE] Sent ABORT command to device');
      } catch (e) {
        debugPrint('[BLE] Failed to send ABORT: $e');
      }
    }
  }

  @override
  Future<void> sendCommand(String command) async {
    if (_writeCharacteristic != null) {
      try {
        await _writeCharacteristic!.write(utf8.encode("$command\n"), withoutResponse: false);
        debugPrint('[BLE] Sent $command command to device');
      } catch (e) {
        debugPrint('[BLE] Failed to send $command: $e');
      }
    } else {
      debugPrint('[BLE] Warning: No writable characteristic to send command');
    }
  }

  @override
  Future<void> disconnect() async {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _jsonBuffer = '';
    _historyCsvBuffer = ''; // Reset buffer riwayat agar tidak terbawa ke koneksi baru
    await _dataSubscription?.cancel();
    _dataSubscription = null;
    await _connSub?.cancel();
    _connSub = null;
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (_) {}
      _connectedDevice = null;
    }
    _writeCharacteristic = null; // Bersihkan juga saat manual disconnect
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }
  }

  @override
  void dispose() {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _dataSubscription?.cancel();
    _connSub?.cancel();
    _dataController.close();
    _connectionController.close();
  }
}
