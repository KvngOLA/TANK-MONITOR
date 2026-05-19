import 'package:flutter/foundation.dart';
import '../models/telemetry.dart';
import '../services/socket_service.dart';

class TelemetryProvider extends ChangeNotifier {
  Telemetry? _current;
  Telemetry? get current => _current;

  TelemetryProvider() {
    // Initialize socket connection
    SocketService().connect(this);
  }

  void update(Telemetry telemetry) {
    _current = telemetry;
    notifyListeners();
  }
}
