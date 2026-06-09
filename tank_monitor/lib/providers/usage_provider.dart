// import 'package:flutter/foundation.dart';
// import '../models/usage.dart';
// import '../services/api_service.dart';

// class UsageProvider extends ChangeNotifier {
//   List<UsageEntry> _entries = [];
//   List<UsageEntry> get entries => _entries;

//   UsageProvider() {
//     fetchUsage();
//   }

//   Future<void> fetchUsage() async {
//     _entries = await ApiService.fetchUsage();
//     notifyListeners();
//   }
// }

import 'package:flutter/material.dart';

class UsageEntry {
  final double level;
  final DateTime time;
  UsageEntry({required this.level, required this.time});
}

class UsageProvider extends ChangeNotifier {
  // Generates placeholder line elements if live database rows are empty
  List<UsageEntry> _entries = List.generate(
    7,
    (index) => UsageEntry(
      level: 40.0 + (index * 5),
      time: DateTime.now().subtract(Duration(hours: 7 - index)),
    ),
  );

  List<UsageEntry> get entries => _entries;

  void setEntries(List<UsageEntry> newEntries) {
    _entries = newEntries;
    notifyListeners();
  }
}