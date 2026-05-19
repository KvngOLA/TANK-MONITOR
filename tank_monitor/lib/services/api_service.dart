import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usage.dart';
import '../models/telemetry.dart';

class ApiService {
  // static const String baseUrl = 'http://196.223.125.101:2026';
  // static const String baseUrl = "http://192.168.137.1:2026";
   static const String baseUrl = "https://tapering-flyer-unmasked.ngrok-free.dev";
  // static const String baseUrl = 'http://10.0.2.2:2026';

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
