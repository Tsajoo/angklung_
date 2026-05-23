class ThresholdEvent {
  String id;
  int timestamp;
  double suhu;
  double ph;
  int ppm;
  double thresholdLimit;
  String sensorType;

  ThresholdEvent({
    required this.id,
    required this.timestamp,
    required this.suhu,
    required this.ph,
    required this.ppm,
    required this.thresholdLimit,
    required this.sensorType,
  });

  Map<String, dynamic> toMap() => {
    'timestamp': timestamp,
    'suhu': suhu,
    'ph': ph,
    'ppm': ppm,
    'thresholdLimit': thresholdLimit,
    'sensorType': sensorType,
  };

  factory ThresholdEvent.fromMap(String id, Map<String, dynamic> map) {
    return ThresholdEvent(
      id: id,
      timestamp: map['timestamp'] ?? 0,
      suhu: (map['suhu'] ?? 0).toDouble(),
      ph: (map['ph'] ?? 0).toDouble(),
      ppm: map['ppm'] ?? 0,
      thresholdLimit: (map['thresholdLimit'] ?? 0).toDouble(),
      sensorType: map['sensorType'] ?? '',
    );
  }
}