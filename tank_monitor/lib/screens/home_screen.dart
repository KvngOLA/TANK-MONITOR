import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/telemetry_provider.dart';
import '../providers/usage_provider.dart';
import '../services/api_service.dart';
import '../widgets/tank_painter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final telemetryProvider = Provider.of<TelemetryProvider>(context);
    final usageProvider = Provider.of<UsageProvider>(context);
    final telemetry = telemetryProvider.current;
    final levelPercent = telemetry?.level ?? 0.0;
    final ph = telemetry?.ph ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Tank Monitor')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Tank illustration
            SizedBox(
              height: 200,
              width: 120,
              child: CustomPaint(
                painter: TankPainter(level: levelPercent / 100),
                child: Center(
                  child: Text('${levelPercent.toStringAsFixed(1)}%'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('PH: ${ph.toStringAsFixed(2)}'),
            const Divider(height: 32),
            // Usage chart placeholder
            const Text('Water Usage (last 24h)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Expanded(
              child: usageProvider.entries.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : LineChart(_buildLineChart(usageProvider.entries)),
            ),
            const Divider(height: 32),
            // Pump control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await ApiService.sendPumpCommand('on');
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pump turned ON')));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: const Text('Pump ON'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await ApiService.sendPumpCommand('off');
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pump turned OFF')));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: const Text('Pump OFF'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildLineChart(List<dynamic> entries) {
    // Convert entries to FlSpot list (assuming entries are UsageEntry objects)
    final spots = entries
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.level))
        .toList();
    return LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          barWidth: 2,
          color: Colors.blueAccent,
        ),
      ],
      titlesData: FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(show: false),
    );
  }
}
