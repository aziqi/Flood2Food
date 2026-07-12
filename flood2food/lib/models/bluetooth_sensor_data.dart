class BluetoothSensorData {
  final String nodeId;
  final String waktu;
  final String tanggal;
  final double suhu;
  final double humi;
  final double kond;
  final double ph;
  final double n;
  final double p;
  final double k;
  final double sd;
  final int lora;
  final bool modeHemat;
  final String status;

  BluetoothSensorData({
    required this.nodeId,
    required this.waktu,
    required this.tanggal,
    required this.suhu,
    required this.humi,
    required this.kond,
    required this.ph,
    required this.n,
    required this.p,
    required this.k,
    required this.sd,
    required this.lora,
    required this.modeHemat,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'node_id': nodeId,
    'waktu': waktu,
    'tanggal': tanggal,
    'suhu': suhu,
    'humi': humi,
    'kond': kond,
    'ph': ph,
    'n': n,
    'p': p,
    'k': k,
    'sd': sd,
    'lora': lora,
    'mode_hemat': modeHemat,
    'status': status,
  };

  factory BluetoothSensorData.fromJson(Map<String, dynamic> json) {
    String parsedWaktu = json['waktu'] as String? ?? '';
    String parsedTanggal = json['tanggal'] as String? ?? '';
    
    if (json.containsKey('timestamp')) {
      final ts = json['timestamp'] as String;
      if (ts.contains('T')) {
        final parts = ts.split('T');
        parsedTanggal = parts[0];
        parsedWaktu = parts[1];
      }
    }

    String statusStr = json['status'] as String? ?? '';
    if (statusStr.isEmpty && json.containsKey('type')) {
      final type = json['type'];
      final msg = json['msg'] ?? '';
      if (type == 'success' || type == 'error') {
         statusStr = '${type}_$msg';
      }
    }

    return BluetoothSensorData(
      nodeId: json['node_id'] as String? ?? 'SYSTEM',
      waktu: parsedWaktu,
      tanggal: parsedTanggal,
      suhu: (json['temperature'] as num?)?.toDouble() ?? (json['suhu'] as num?)?.toDouble() ?? 0,
      humi: (json['humidity'] as num?)?.toDouble() ?? (json['humi'] as num?)?.toDouble() ?? 0,
      kond: (json['ec'] as num?)?.toDouble() ?? (json['kond'] as num?)?.toDouble() ?? 0,
      ph: (json['ph'] as num?)?.toDouble() ?? 7.0,
      n: (json['nitrogen'] as num?)?.toDouble() ?? (json['n'] as num?)?.toDouble() ?? 0,
      p: (json['phosphorus'] as num?)?.toDouble() ?? (json['p'] as num?)?.toDouble() ?? 0,
      k: (json['kalium'] as num?)?.toDouble() ?? (json['k'] as num?)?.toDouble() ?? 0,
      sd: json['sd'] == true ? 1.0 : (json['sd'] == false ? 0.0 : (json['sd'] as num?)?.toDouble() ?? 0),
      lora: json['lora'] == true ? 1 : (json['lora'] == false ? 0 : (json['lora'] as int?) ?? 0),
      modeHemat: json['mode_hemat'] == true || json['mode_hemat'] == 1 || json['mode_hemat'] == "1",
      status: statusStr,
    );
  }

  BluetoothSensorData copyWith({
    String? nodeId,
    String? waktu,
    String? tanggal,
    double? suhu,
    double? humi,
    double? kond,
    double? ph,
    double? n,
    double? p,
    double? k,
    double? sd,
    int? lora,
    bool? modeHemat,
    String? status,
  }) =>
      BluetoothSensorData(
        nodeId: nodeId ?? this.nodeId,
        waktu: waktu ?? this.waktu,
        tanggal: tanggal ?? this.tanggal,
        suhu: suhu ?? this.suhu,
        humi: humi ?? this.humi,
        kond: kond ?? this.kond,
        ph: ph ?? this.ph,
        n: n ?? this.n,
        p: p ?? this.p,
        k: k ?? this.k,
        sd: sd ?? this.sd,
        lora: lora ?? this.lora,
        modeHemat: modeHemat ?? this.modeHemat,
        status: status ?? this.status,
      );
}
