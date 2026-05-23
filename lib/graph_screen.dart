import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'services/firebase_service.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseService _firebase = FirebaseService();

  // Rolling buffers (max 20 points)
  final List<FlSpot> _suhuSpots = [];
  final List<FlSpot> _phSpots = [];
  final List<FlSpot> _ppmSpots = [];
  int _suhuCount = 0;
  int _phCount = 0;
  int _ppmCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _listenToSensors();
  }

  void _listenToSensors() {
    _firebase.getSuhuStream().listen((value) {
      setState(() {
        _suhuSpots.add(FlSpot(_suhuCount.toDouble(), value));
        _suhuCount++;
        if (_suhuSpots.length > 20) _suhuSpots.removeAt(0);
      });
    });
    _firebase.getPhStream().listen((value) {
      setState(() {
        _phSpots.add(FlSpot(_phCount.toDouble(), value));
        _phCount++;
        if (_phSpots.length > 20) _phSpots.removeAt(0);
      });
    });
    _firebase.getPpmStream().listen((value) {
      setState(() {
        _ppmSpots.add(FlSpot(_ppmCount.toDouble(), value.toDouble()));
        _ppmCount++;
        if (_ppmSpots.length > 20) _ppmSpots.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grafik Sensor'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Suhu'),
            Tab(text: 'pH'),
            Tab(text: 'PPM'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLineChart(_suhuSpots, Colors.orange, 'Suhu (°C)'),
          _buildLineChart(_phSpots, Colors.green, 'pH'),
          _buildLineChart(_ppmSpots, Colors.blue, 'PPM'),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<FlSpot> spots, Color color, String title) {
    if (spots.isEmpty) {
      return const Center(child: Text('Menunggu data sensor...'));
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: const FlTitlesData(show: true),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }
}