import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usage.dart';
import '../models/telemetry.dart';

class ApiService {
  //development
   static const String baseUrl = "https://tapering-flyer-unmasked.ngrok-free.dev";

  //production
  // static const String baseUrl = "https://tank-monitor-production-399d.up.railway.app";

  // Fetch current pump status (on/off)
  static Future<bool> fetchPumpStatus() async {
    final response = await http.get(Uri.parse('$baseUrl/pump/status'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // Expecting {"state": "on"} or {"state": "off"}
      final state = data['state']?.toString().toLowerCase();
      return state == 'on' || state == 'true';
    } else {
      throw Exception('Failed to load pump status');
    }
  }

  // Fetch past usage data
  static Future<List<UsageEntry>> fetchUsage() async {
    final response = await http.get(Uri.parse('$baseUrl/usage'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => UsageEntry.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load usage data');
    }
  }

  // Send pump command (on/off)
  static Future<void> sendPumpCommand(String state) async {
    final response = await http.post(
      Uri.parse('${baseUrl}/command'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'state': state}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to send pump command');
    }
  }
}
