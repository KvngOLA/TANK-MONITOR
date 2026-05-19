import 'package:flutter/foundation.dart';
import '../models/usage.dart';
import '../services/api_service.dart';

class UsageProvider extends ChangeNotifier {
  List<UsageEntry> _entries = [];
  List<UsageEntry> get entries => _entries;

  UsageProvider() {
    fetchUsage();
  }

  Future<void> fetchUsage() async {
    _entries = await ApiService.fetchUsage();
    notifyListeners();
  }
}
