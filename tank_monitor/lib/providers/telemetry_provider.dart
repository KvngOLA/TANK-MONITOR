// import 'package:flutter/foundation.dart';
// import '../models/telemetry.dart';
// import '../services/socket_service.dart';

// class TelemetryProvider extends ChangeNotifier {
//   Telemetry? _current;
//   Telemetry? get current => _current;

//   TelemetryProvider() {
//     // Initialize socket connection
//     SocketService().connect(this);
//   }

//   void update(Telemetry telemetry) {
//     _current = telemetry;
//     notifyListeners();
//   }
// }


import 'package:flutter/material.dart';

class TelemetryModel {
  final double level;
  final double ph;
  TelemetryModel({required this.level, required this.ph});
}

class TelemetryProvider extends ChangeNotifier {
  TelemetryModel? _current;

  TelemetryModel? get current => _current;

  void updateTelemetry(double level, double ph) {
    _current = TelemetryModel(level: level, ph: ph);
    notifyListeners();
  }
}