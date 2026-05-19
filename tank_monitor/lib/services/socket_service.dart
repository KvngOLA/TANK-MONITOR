import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/telemetry.dart';
import '../providers/telemetry_provider.dart';

class SocketService {
  late IO.Socket _socket;

  void connect(TelemetryProvider provider) {
    _socket = IO.io('http://196.223.125.127:2026', <String, dynamic>{
      'transports': ['websocket'],
    });
    _socket.onConnect((_) {
      // Connected
    });
    _socket.on('telemetry', (data) {
      final telemetry = Telemetry.fromJson(Map<String, dynamic>.from(data));
      provider.update(telemetry);
    });
    _socket.onError((error) {
      // Handle error
    });
  }

  void disconnect() {
    _socket.disconnect();
  }
}
