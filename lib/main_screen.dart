import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/firebase_service.dart';
import 'models/threshold_event.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final FirebaseService _firebase = FirebaseService();

  // Sensor values
  double suhu = 0.0;
  double ph = 0.0;
  int ppm = 0;

  // Thresholds
  double suhuThreshold = 40.0;
  double phThreshold = 8.5;
  int ppmThreshold = 1000;

  // Controllers for threshold inputs
  final TextEditingController _suhuController = TextEditingController();
  final TextEditingController _phController = TextEditingController();
  final TextEditingController _ppmController = TextEditingController();

  bool _wasExceeded = false;

  @override
  void initState() {
    super.initState();
    _listenToSensors();
    _listenToThresholds();
  }

  void _listenToSensors() {
    _firebase.getSuhuStream().listen((value) {
      setState(() => suhu = value);
      _checkExceedance();
    });
    _firebase.getPhStream().listen((value) {
      setState(() => ph = value);
      _checkExceedance();
    });
    _firebase.getPpmStream().listen((value) {
      setState(() => ppm = value);
      _checkExceedance();
    });
  }

  void _listenToThresholds() {
    _firebase.getSuhuThresholdStream().listen((value) {
      setState(() => suhuThreshold = value);
      _suhuController.text = value.toInt().toString();
    });
    _firebase.getPhThresholdStream().listen((value) {
      setState(() => phThreshold = value);
      _phController.text = value.toStringAsFixed(1);
    });
    _firebase.getPpmThresholdStream().listen((value) {
      setState(() => ppmThreshold = value);
      _ppmController.text = value.toString();
    });
  }

  void _checkExceedance() {
    final suhuExceed = suhu > suhuThreshold;
    final phExceed = ph > phThreshold;
    final ppmExceed = ppm > ppmThreshold;
    final anyExceed = suhuExceed || phExceed || ppmExceed;

    if (anyExceed && !_wasExceeded) {
      String sensorType;
      double limit;
      if (suhuExceed) {
        sensorType = 'suhu';
        limit = suhuThreshold;
      } else if (phExceed) {
        sensorType = 'ph';
        limit = phThreshold;
      } else {
        sensorType = 'ppm';
        limit = ppmThreshold.toDouble();
      }
      final event = ThresholdEvent(
        id: '',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        suhu: suhu,
        ph: ph,
        ppm: ppm,
        thresholdLimit: limit,
        sensorType: sensorType,
      );
      _firebase.saveThresholdEvent(event);
      _wasExceeded = true;
    } else if (!anyExceed) {
      _wasExceeded = false;
    }
  }

  Future<void> _saveThresholds() async {
    final newSuhu = double.tryParse(_suhuController.text) ?? 40.0;
    final newPh = double.tryParse(_phController.text) ?? 8.5;
    final newPpm = int.tryParse(_ppmController.text) ?? 1000;
    await _firebase.updateSuhuThreshold(newSuhu);
    await _firebase.updatePhThreshold(newPh);
    await _firebase.updatePpmThreshold(newPpm);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ambang batas disimpan')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biogas Monitor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sensor cards
            Card(
              child: ListTile(
                title: const Text('🌡️ SUHU'),
                trailing: Text('${suhu.toStringAsFixed(1)} °C',
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: const Text('💧 pH AIR'),
                trailing: Text(ph.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: const Text('⛽ METANA'),
                trailing: Text('$ppm ppm',
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('⚙️ AMBANG BATAS',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _suhuController,
                    decoration: const InputDecoration(
                        labelText: 'Suhu max (°C)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _phController,
                    decoration: const InputDecoration(
                        labelText: 'pH max', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _ppmController,
                    decoration: const InputDecoration(
                        labelText: 'PPM max', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveThresholds,
              child: const Text('Simpan Semua'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Graphs'),
        ],
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            Navigator.pushNamed(context, '/history');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/graph');
          }
        },
      ),
    );
  }
}