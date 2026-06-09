import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO; // Import socket client
import '../models/usage.dart';
import '../models/telemetry.dart';

class ApiService {
  // Production Base URL
  static const String baseUrl = "https://tank-monitor-production-399d.up.railway.app";
  static IO.Socket? _socket;

  // ==================== WEBSOCKET (REAL-TIME TELEMETRY) ====================
  
  static void connectWebSocket({
    required Function(Map<String, dynamic>) onTelemetryReceived,
    Function(dynamic)? onConnectError,
  }) {
    // If already connected, don't spin up another instance
    if (_socket != null && _socket!.connected) return;

    // Configure and connect to your live Railway backend URL
    _socket = IO.io(baseUrl, IO.OptionBuilder()
      .setTransports(['websocket']) // Force WebSocket transport protocol
      .enableAutoConnect()          // Automatically connect on initialization
      .build());

    _socket!.onConnect((_) {
      print('Flutter connected to Backend WebSocket channel!');
    });

    // Listen directly for the event string your Node.js backend emits: io.emit("telemetry")
    _socket!.on('telemetry', (data) {
      print('Live Telemetry Payload received in App: $data');
      
      // Handle both raw Map or encoded JSON string gracefully
      if (data is String) {
        onTelemetryReceived(jsonDecode(data) as Map<String, dynamic>);
      } else if (data is Map) {
        onTelemetryReceived(Map<String, dynamic>.from(data));
      }
    });

    _socket!.onConnectError((err) {
      print('WebSocket Connection Error: $err');
      if (onConnectError != null) onConnectError(err);
    });

    _socket!.onDisconnect((_) => print('WebSocket Connection Closed'));
  }

  static void disconnectWebSocket() {
    _socket?.disconnect();
    _socket = null;
  }

  // ==================== HTTP SERVICES (REST API) ====================

// 1. Fixed to hit your new /status route
  static Future<bool> fetchPumpStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/status'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'ACTIVE';
      }
      return false;
    } catch (e) {
      throw Exception('Failed to load pump status');
    }
  }

  // Fetch past usage data (Fine for HTTP since it's historical logs)
  // static Future<List<UsageEntry>> fetchUsage() async {
  //   final response = await http.get(Uri.parse('$baseUrl/usage'));
  //   if (response.statusCode == 200) {
  //     final List<dynamic> data = jsonDecode(response.body);
  //     return data.map((e) => UsageEntry.fromJson(e as Map<String, dynamic>)).toList();
  //   } else {
  //     throw Exception('Failed to load usage data');
  //   }
  // }

  // Pointed historical data tracking directly to your real /usage route
  static Future<List<Map<String, dynamic>>> fetchHistoricalData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/usage')); 
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      print("Error fetching chart data: $e");
      return [];
    }
  }


  // Send pump command (on/off)
  static Future<void> sendPumpCommand(String command) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/command'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'state': command.toUpperCase()}),
      );
      if (response.statusCode != 200) {
        throw Exception('Server rejected command');
      }
    } catch (e) {
      throw Exception('Failed to dispatch pump command: $e');
    }
  }
}