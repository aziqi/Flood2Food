import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../models/sensor_data.dart';
import '../services/sensor_log_service.dart';
import '../bloc/sensor/sensor_bloc.dart';
import '../bloc/sensor/sensor_event.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum FilterMode { semua, hari, bulan }

class SensorLogScreen extends StatefulWidget {
  const SensorLogScreen({super.key});

  @override
  State<SensorLogScreen> createState() => _SensorLogScreenState();
}

class _SensorLogScreenState extends State<SensorLogScreen> {
  final SensorLogService _logService = SensorLogService();
  List<SensorData> _allLogs = [];
  List<SensorData> _filteredLogs = [];
  bool _loading = true;

  FilterMode _filterMode = FilterMode.semua;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    final logs = await _logService.loadLog();
    setState(() {
      _allLogs = logs.reversed.toList();
      _applyFilter();
      _loading = false;
    });
  }

  void _applyFilter() {
    switch (_filterMode) {
      case FilterMode.semua:
        _filteredLogs = List.from(_allLogs);
        break;
      case FilterMode.hari:
        _filteredLogs = _allLogs.where((log) {
          return log.timestamp.year == _selectedDate.year &&
              log.timestamp.month == _selectedDate.month &&
              log.timestamp.day == _selectedDate.day;
        }).toList();
        break;
      case FilterMode.bulan:
        _filteredLogs = _allLogs.where((log) {
          return log.timestamp.year == _selectedDate.year &&
              log.timestamp.month == _selectedDate.month;
        }).toList();
        break;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: _filterMode == FilterMode.hari
          ? 'Pilih Tanggal'
          : 'Pilih Bulan (Tanggal Diabaikan)',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _applyFilter();
      });
    }
  }

  String _formatTimestamp(DateTime dt) {
    return DateFormat('dd/MM/yy HH:mm:ss').format(dt);
  }

  String _filterLabel() {
    switch (_filterMode) {
      case FilterMode.semua:
        return 'Semua Data';
      case FilterMode.hari:
        return DateFormat('dd MMMM yyyy').format(_selectedDate);
      case FilterMode.bulan:
        return DateFormat('MMMM yyyy').format(_selectedDate);
    }
  }

  // Group logs by date for section headers
  Map<String, List<SensorData>> _groupByDate() {
    final Map<String, List<SensorData>> grouped = {};
    for (final log in _filteredLogs) {
      final key = DateFormat('dd MMMM yyyy').format(log.timestamp);
      grouped.putIfAbsent(key, () => []).add(log);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDate();
    final dateKeys = grouped.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Sensor'),
        actions: [
          if (_allLogs.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.file_download),
              tooltip: 'Export CSV',
              onPressed: () async {
                await _logService.exportToCsv();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Menyiapkan file CSV untuk di-share...')),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.cloud_download),
              tooltip: 'Tarik Ulang Semua SD Card',
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Tarik Ulang Semua Riwayat'),
                  content: const Text('Ini akan memaksa Node untuk mengirim ulang SELURUH data SD Card dari awal. Mungkin memakan waktu agak lama. Lanjutkan?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.read<SensorBloc>().add(FetchAllNodeDataEvent());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Meminta seluruh riwayat dari awal...')),
                        );
                      },
                      child: const Text('Ya, Tarik Semua'),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Hapus Data Lokal',
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Hapus Data Lokal'),
                  content: const Text('Apakah Anda yakin ingin menghapus semua data sensor yang tersimpan di memori HP ini?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.read<SensorBloc>().add(ClearSensorLog());
                        setState(() {
                          _allLogs.clear();
                          _filteredLogs.clear();
                        });
                      },
                      child: const Text('Hapus',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter chips
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildFilterChip('Semua', FilterMode.semua),
                          const SizedBox(width: 8),
                          _buildFilterChip('Per Hari', FilterMode.hari),
                          const SizedBox(width: 8),
                          _buildFilterChip('Per Bulan', FilterMode.bulan),
                        ],
                      ),
                      if (_filterMode != FilterMode.semua) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer),
                                const SizedBox(width: 8),
                                Text(
                                  _filterLabel(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down,
                                    size: 20,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${_filteredLogs.length} dari ${_allLogs.length} data',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Log list
                Expanded(
                  child: _filteredLogs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                _allLogs.isEmpty
                                    ? 'Belum ada riwayat sensor'
                                    : 'Tidak ada data untuk filter ini',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadLogs,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(
                                left: 8, right: 8, top: 4, bottom: 16),
                            itemCount: _countItemsWithHeaders(
                                dateKeys, grouped),
                            itemBuilder: (context, index) {
                              final item = _getItemAtIndex(
                                  index, dateKeys, grouped);
                              if (item is String) {
                                // Date header
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      left: 8, top: 12, bottom: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_month,
                                          size: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        item,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              final log = item as SensorData;
                              return _buildLogCard(log);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  int _countItemsWithHeaders(
      List<String> dateKeys, Map<String, List<SensorData>> grouped) {
    int count = 0;
    for (final key in dateKeys) {
      count += 1 + grouped[key]!.length; // 1 header + items
    }
    return count;
  }

  dynamic _getItemAtIndex(
      int index, List<String> dateKeys, Map<String, List<SensorData>> grouped) {
    int cursor = 0;
    for (final key in dateKeys) {
      if (index == cursor) return key; // header
      cursor++;
      final items = grouped[key]!;
      if (index < cursor + items.length) {
        return items[index - cursor];
      }
      cursor += items.length;
    }
    return '';
  }

  Widget _buildFilterChip(String label, FilterMode mode) {
    final selected = _filterMode == mode;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _filterMode = mode;
          _applyFilter();
        });
      },
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildLogCard(SensorData log) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(log.timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _healthColor(log.plantHealthScore)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    log.healthStatus,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _healthColor(log.plantHealthScore),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _sensorRow(Icons.thermostat, 'Suhu',
                '${log.temperature.toStringAsFixed(1)}°C'),
            _sensorRow(Icons.water_drop, 'Humidity',
                '${log.humidity.toStringAsFixed(1)}%'),
            _sensorRow(Icons.science, 'pH', log.ph.toStringAsFixed(2)),
            _sensorRow(
                Icons.flash_on, 'EC', '${log.ec.toStringAsFixed(2)} mS/cm'),
            _sensorRow(Icons.grass, 'N',
                '${log.nitrogen.toStringAsFixed(1)} mg/kg'),
            _sensorRow(
                Icons.bolt, 'P', '${log.phosphorus.toStringAsFixed(1)} mg/kg'),
            _sensorRow(Icons.water, 'K',
                '${log.kalium.toStringAsFixed(1)} mg/kg'),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutQuint);
  }

  Color _healthColor(double score) {
    if (score >= 85) return Colors.green;
    if (score >= 65) return Colors.lightGreen;
    if (score >= 45) return Colors.orange;
    return Colors.red;
  }

  Widget _sensorRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
