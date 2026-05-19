class Telemetry {
  final double level; // percentage 0-100
  final double ph;
  final DateTime? timestamp;

  Telemetry({required this.level, required this.ph, this.timestamp});

  factory Telemetry.fromJson(Map<String, dynamic> json) {
    return Telemetry(
      level: (json['level'] as num).toDouble(),
      ph: (json['ph'] as num).toDouble(),
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'level': level,
        'ph': ph,
        if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
      };
}
