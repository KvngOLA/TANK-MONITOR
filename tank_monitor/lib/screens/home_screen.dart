import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/telemetry_provider.dart';
import '../providers/usage_provider.dart';
import '../services/api_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../widgets/tank_painter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // Socket for real‑time updates
  late final IO.Socket _socket;
  bool _pumpOn = false; // true = pump active
  bool _loading = false;
  late final AnimationController _waveController;
  double _wavePhase = 0.0;

  // Local state variables to catch real-time socket streams instantly
  double? _localLevel;
  double? _localPh;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..addListener(() {
        setState(() {
          _wavePhase = _waveController.value * 2 * 3.1415926;
        });
      })
      ..repeat();
      
    // Load data from backend layers
    _loadChartData(); // Automatically populates graph on screen boot
    _setupSocket();
  }

  // Initialize socket listeners for telemetry and command updates
  void _setupSocket() {
    _socket = IO.io("https://tank-monitor-production-399d.up.railway.app", <String, dynamic>{
      'transports': ['websocket'],
    });

    // FRESH-OPENING TRIGGER: Catches the current state immediately upon launching the app
    _socket.on('pump-status', (data) {
      try {
        if (data != null && data['isPumpActive'] != null) {
          setState(() {
            _pumpOn = data['isPumpActive'] == true;
          });
        }
      } catch (e) {
        debugPrint("Error handling fresh startup pump status payload: $e");
      }
    });

    // Listen to the "telemetry" channel and update the UI variables directly
    _socket.on('telemetry', (data) {
      try {
        if (data != null) {
          setState(() {
            _localLevel = double.parse((data['level_pct'] ?? data['level'] ?? 0.0).toString());
            _localPh = double.parse((data['ph'] ?? 7.0).toString());
          });
        }
      } catch (e) {
        debugPrint("Error parsing real-time telemetry socket data: $e");
      }
    });

    // REACTIVE FIX: Listens to server broadcast to safely flip button states
    _socket.on('command-published', (data) {
      try {
        if (data != null && data['state'] != null) {
          final String incomingState = data['state'].toString().trim().toUpperCase();
          
          setState(() {
            _pumpOn = (incomingState == 'ON');
          });
        }
      } catch (e) {
        debugPrint("Socket status parse error: $e");
      }
    });

    _socket.onError((error) {
      showTopNotification(message: 'Socket error: $error', isError: true);
    });
  }

  // Pulls actual database telemetry data rows to render your line chart
  Future<void> _loadChartData() async {
    try {
      final historicalData = await ApiService.fetchHistoricalData();
      if (historicalData.isNotEmpty) {
        final usageProvider = Provider.of<UsageProvider>(context, listen: false);
        
        List<UsageEntry> loadedEntries = historicalData.map((row) {
          return UsageEntry(
            level: double.parse((row['averageLevel'] ?? 0.0).toString()),
            time: row['createdAt'] != null 
                ? DateTime.parse(row['createdAt'].toString())
                : DateTime.now(),
          );
        }).toList();

        usageProvider.setEntries(loadedEntries);
      }
    } catch (e) {
      debugPrint("Error processing historical data overlay: $e");
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _socket.disconnect(); // Closes down socket connection cleanly
    super.dispose();
  }

  /// Custom floating Material 3 style notification system that presents at the top
  void showTopNotification({required String message, bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red[900] : Colors.green[900],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError ? Colors.red[900] : Colors.green[900],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red[50] : Colors.green[50],
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 160,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  // DECOUPLED FIX: Handed state mutations completely off to the socket layer
  Future<void> _togglePump() async {
    setState(() => _loading = true);
    try {
      final String targetState = _pumpOn ? 'OFF' : 'ON';
      _socket.emit('toggle-pump-request', targetState);
      showTopNotification(message: 'Sending command: $targetState');
    } catch (e) {
      showTopNotification(message: 'Error: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = Provider.of<TelemetryProvider>(context).current;
    final usageProvider = Provider.of<UsageProvider>(context);

    // Prioritize live local socket variables; fall back to global provider if null
    final levelPercent = _localLevel ?? telemetry?.level ?? 0.0;
    final ph = _localPh ?? telemetry?.ph ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tank Monitor'),
        backgroundColor: const Color(0xFFFBFDFB),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFFBFDFB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Upper Dashboard Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT SIDE: Tank Card
                Expanded(
                  flex: 6,
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: AspectRatio(
                        aspectRatio: 0.65,
                        child: CustomPaint(
                          painter: TankPainter(level: levelPercent / 100, wavePhase: _wavePhase),
                          child: Center(
                            child: Text(
                              '${levelPercent.toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // RIGHT SIDE: Controls Column
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      // Neumorphic Power Button
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          GestureDetector(
                            onTap: _loading ? null : _togglePump,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: _pumpOn
                                    ? const LinearGradient(
                                        colors: [Color(0xFF64C7A4), Color(0xFF009688)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : const LinearGradient(
                                        colors: [Color(0xFFE0E0E0), Color(0xFFBDBDBD)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _pumpOn ? Colors.greenAccent.withOpacity(0.6) : Colors.grey.withOpacity(0.4),
                                    spreadRadius: 4,
                                    blurRadius: 12,
                                  ),
                                ],
                                border: Border.all(
                                  color: _pumpOn ? Colors.green[600]! : Colors.grey,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.power_settings_new,
                                  color: _pumpOn ? Colors.white : Colors.grey[700],
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                          if (_loading)
                            const SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // pH Metric Card
                      Card(
                        color: Colors.green[50],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text('PH: ${ph.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Pump Status Indicator Card
                      Card(
                        color: const Color(0xFFE8F5E9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Icon(Icons.circle,
                                color: _pumpOn ? Colors.green : Colors.red,
                                size: 12,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Pump Status: ${_pumpOn ? 'ACTIVE' : 'INACTIVE'}',
                                  style: const TextStyle(fontSize: 16, color: Color(0xFF1B5E20)),
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Lower Dashboard Section
            const Text('Water Usage (last 24h)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 4,
              child: SizedBox(
                height: 250,
                child: usageProvider.entries.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : LineChart(_buildLineChart(usageProvider.entries)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildLineChart(List<dynamic> entries) {
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
          color: Colors.green[600],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.green[600]!.withOpacity(0.15),
          ),
        ),
      ],
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
    );
  }
}