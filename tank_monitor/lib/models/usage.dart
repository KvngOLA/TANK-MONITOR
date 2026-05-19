class UsageEntry {
  final double level;
  final double ph;
  final DateTime timestamp;

  UsageEntry({required this.level, required this.ph, required this.timestamp});

  factory UsageEntry.fromJson(Map<String, dynamic> json) {
    return UsageEntry(
      level: (json['level'] as num).toDouble(),
      ph: (json['ph'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
