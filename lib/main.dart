import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyC-siZ2Z3VQU3bbMjsfflauRzZRdjfiEKA",
        appId: "1:25429940980:ios:45d0365544b4624c755ca1",
        messagingSenderId: "25429940980",
        projectId: "biogas11",
        databaseURL:
            "https://biogas11-default-rtdb.asia-southeast1.firebasedatabase.app",
        storageBucket: "biogas11.firebasestorage.app",
      ),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () =>
          throw Exception("Firebase init timed out — check network / ATS"),
    );

    FirebaseDatabase.instance.setPersistenceEnabled(true);
    FirebaseDatabase.instance.ref('realtime').keepSynced(true);
    FirebaseDatabase.instance.ref('history').keepSynced(true);
    FirebaseDatabase.instance.ref('config').keepSynced(true);
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFF5F0EB),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              "Startup Error:\n$e",
              style: const TextStyle(
                  color: Color(0xFFE07C7C),
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ));
    return;
  }

  runApp(const BiogasApp());
}

// ── Pastel colour palette ────────────────────────────────────────────────────
class AppColors {
  static const bg         = Color(0xFFF7F4F0);
  static const card       = Color(0xFFFFFFFF);
  static const green      = Color(0xFF7EC8A4);
  static const greenLight = Color(0xFFD6F0E4);
  static const red        = Color(0xFFE8857A);
  static const redLight   = Color(0xFFFCE0DE);
  static const blue       = Color(0xFF85B4D4);
  static const blueLight  = Color(0xFFD6EAF7);
  static const peach      = Color(0xFFF5C49A);
  static const peachLight = Color(0xFFFFF0E0);
  static const text       = Color(0xFF3A3A3A);
  static const textLight  = Color(0xFF8A8A8A);
  static const divider    = Color(0xFFEAE6E1);
}

class BiogasApp extends StatelessWidget {
  const BiogasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biogas Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.bg,
        fontFamily: 'SF Pro Display',
        colorScheme: ColorScheme.light(
          primary: AppColors.green,
          surface: AppColors.card,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.card,
          selectedItemColor: AppColors.green,
          unselectedItemColor: AppColors.textLight,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// ── Main screen ──────────────────────────────────────────────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    RealtimeTab(),
    HistoryTab(),
    GraphTab(),
  ];

  final List<String> _titles = ['Live Sensors', 'History', 'Graph'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titles[_currentIndex],
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const Text(
              'Biogas Monitor',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: _tabs[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            backgroundColor: Colors.transparent,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.sensors_outlined),
                  activeIcon: Icon(Icons.sensors),
                  label: 'Live'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.history_outlined),
                  activeIcon: Icon(Icons.history),
                  label: 'History'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.show_chart_outlined),
                  activeIcon: Icon(Icons.show_chart),
                  label: 'Graph'),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared helpers ───────────────────────────────────────────────────────────
double _parse(dynamic value) {
  if (value == null) return 0.0;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

// ── 1. Realtime Tab ──────────────────────────────────────────────────────────
class RealtimeTab extends StatelessWidget {
  const RealtimeTab({super.key});

  void _editThreshold(BuildContext context, String key, double current) {
    final ctrl = TextEditingController(text: current.toStringAsFixed(1));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Edit Threshold',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text)),
            const SizedBox(height: 4),
            Text(key,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textLight)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final v = double.tryParse(ctrl.text);
                  if (v != null) {
                    FirebaseDatabase.instance
                        .ref('config')
                        .update({key: v});
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Save',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sensorCard(
    BuildContext context, {
    required String title,
    required String unit,
    required double value,
    required double threshold,
    required String configKey,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    final bool danger = value > threshold;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text)),
              ),
              // Status pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: danger ? AppColors.redLight : AppColors.greenLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  danger ? 'BAHAYA' : 'AMAN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: danger ? AppColors.red : AppColors.green,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Big value
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(unit,
                    style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          // Threshold row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_outlined,
                      size: 14, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text(
                    'Threshold: ${threshold.toStringAsFixed(1)} $unit',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textLight),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _editThreshold(context, configKey, threshold),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 13, color: AppColors.textLight),
                      SizedBox(width: 4),
                      Text('Edit',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('config').onValue,
      builder: (context, configSnap) {
        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref('realtime').onValue,
          builder: (context, realtimeSnap) {
            if (!configSnap.hasData || !realtimeSnap.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.green, strokeWidth: 2),
              );
            }

            final cfg =
                configSnap.data?.snapshot.value as Map<dynamic, dynamic>? ??
                    {};
            final rt =
                realtimeSnap.data?.snapshot.value as Map<dynamic, dynamic>? ??
                    {};

            return ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [
                _sensorCard(
                  context,
                  title: 'Temperature',
                  unit: '°C',
                  value: _parse(rt['suhu']),
                  threshold: _parse(cfg['suhuThreshold']),
                  configKey: 'suhuThreshold',
                  color: AppColors.peach,
                  bgColor: AppColors.peachLight,
                  icon: Icons.thermostat_outlined,
                ),
                _sensorCard(
                  context,
                  title: 'Gas (MQ Sensor)',
                  unit: 'PPM',
                  value: _parse(rt['ppm']),
                  threshold: _parse(cfg['ppmThreshold']),
                  configKey: 'ppmThreshold',
                  color: AppColors.blue,
                  bgColor: AppColors.blueLight,
                  icon: Icons.air_outlined,
                ),
                _sensorCard(
                  context,
                  title: 'pH Level',
                  unit: 'pH',
                  value: _parse(rt['ph']),
                  threshold: _parse(cfg['phThreshold']),
                  configKey: 'phThreshold',
                  color: AppColors.green,
                  bgColor: AppColors.greenLight,
                  icon: Icons.science_outlined,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── 2. History Tab (with swipe to delete) ────────────────────────────────────
class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  // Helper to delete a history entry with confirmation
  void _confirmDelete(BuildContext context, String key) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              FirebaseDatabase.instance.ref('history').child(key).remove();
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream:
          FirebaseDatabase.instance.ref('history').limitToLast(100).onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.green, strokeWidth: 2));
        }

        final map =
            snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;
        if (map == null) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_outlined,
                    size: 48, color: AppColors.textLight),
                SizedBox(height: 12),
                Text('No history yet',
                    style: TextStyle(
                        color: AppColors.textLight, fontSize: 15)),
              ],
            ),
          );
        }

        final keys = map.keys.toList()
          ..sort();
        final reversed = keys.reversed.toList();

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: reversed.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final key = reversed[index];
            final item = map[key] as Map<dynamic, dynamic>;
            final sensor = item['sensorType'] ?? 'Unknown';

            Color dotColor = AppColors.green;
            if (sensor.toString().toLowerCase().contains('suhu')) {
              dotColor = AppColors.peach;
            } else if (sensor.toString().toLowerCase().contains('ppm') ||
                sensor.toString().toLowerCase().contains('mq')) {
              dotColor = AppColors.blue;
            }

            // Wrap card in Dismissible for swipe-to-delete
            return Dismissible(
              key: Key(key),
              direction: DismissDirection.horizontal,
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_outline,
                    color: Colors.white, size: 24),
              ),
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_outline,
                    color: Colors.white, size: 24),
              ),
              confirmDismiss: (_) {
                _confirmDelete(context, key);
                return Future.value(false); // we handle deletion manually via dialog
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Triggered by: $sensor',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Temp: ${item['suhu'] ?? '-'}°C  ·  PPM: ${item['ppm'] ?? '-'}  ·  pH: ${item['ph'] ?? '-'}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── 3. Graph Tab (with interactive touch tooltips) ───────────────────────────
class GraphTab extends StatefulWidget {
  const GraphTab({super.key});
  @override
  State<GraphTab> createState() => _GraphTabState();
}

class _GraphTabState extends State<GraphTab> {
  String _metric = 'suhu';

  static const _metrics = [
    _MetricOption('suhu',  'Temp °C',  AppColors.peach,  AppColors.peachLight),
    _MetricOption('ppm',   'Gas PPM',  AppColors.blue,   AppColors.blueLight),
    _MetricOption('ph',    'pH',       AppColors.green,  AppColors.greenLight),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _metrics.firstWhere((m) => m.key == _metric);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Metric selector
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: _metrics.map((m) {
              final active = m.key == _metric;
              return GestureDetector(
                onTap: () => setState(() => _metric = m.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? m.color : AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: m.color.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Text(
                    m.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppColors.textLight,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        // Chart
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.fromLTRB(12, 20, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref('history')
                  .limitToLast(20)
                  .onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.green, strokeWidth: 2));
                }

                final map = snapshot.data?.snapshot.value
                    as Map<dynamic, dynamic>?;
                if (map == null || map.isEmpty) {
                  return const Center(
                    child: Text('No data yet',
                        style: TextStyle(
                            color: AppColors.textLight, fontSize: 14)),
                  );
                }

                final sortedKeys = map.keys.toList()..sort();
                final spots = <FlSpot>[];
                for (var i = 0; i < sortedKeys.length; i++) {
                  final item =
                      map[sortedKeys[i]] as Map<dynamic, dynamic>;
                  spots.add(FlSpot(i.toDouble(), _parse(item[_metric])));
                }

                return LineChart(
                  LineChartData(
                    // ★ Touch interaction
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        tooltipBgColor: AppColors.text.withOpacity(0.9),
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final metricLabel = selected.label;
                            return LineTooltipItem(
                              '${spot.y.toStringAsFixed(1)} $metricLabel',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            );
                          }).toList();
                        },
                      ),
                      touchCallback: (event, response) {
                        // Optional: you could add haptic feedback here
                      },
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: AppColors.divider,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: const FlTitlesData(
                      topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: _leftTitle,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: selected.color,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, _, __, ___) =>
                              FlDotCirclePainter(
                            radius: 4,
                            color: AppColors.card,
                            strokeWidth: 2,
                            strokeColor: selected.color,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              selected.color.withOpacity(0.2),
                              selected.color.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

Widget _leftTitle(double value, TitleMeta meta) {
  return Text(
    value.toInt().toString(),
    style:
        const TextStyle(fontSize: 10, color: AppColors.textLight),
    textAlign: TextAlign.right,
  );
}

class _MetricOption {
  final String key;
  final String label;
  final Color color;
  final Color bgColor;
  const _MetricOption(this.key, this.label, this.color, this.bgColor);
}
