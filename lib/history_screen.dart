import 'package:flutter/material.dart';
import 'services/firebase_service.dart';
import 'models/threshold_event.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseService _firebase = FirebaseService();
  List<ThresholdEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _firebase.getHistoryStream().listen((events) {
      setState(() => _events = events);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: _events.isEmpty
          ? const Center(child: Text('Belum ada kejadian ambang batas'))
          : ListView.builder(
              itemCount: _events.length,
              itemBuilder: (ctx, index) {
                final event = _events[index];
                final time = DateFormat('dd/MM/yyyy HH:mm:ss')
                    .format(DateTime.fromMillisecondsSinceEpoch(event.timestamp));
                String reason;
                if (event.sensorType == 'suhu') {
                  reason = 'Suhu melebihi ${event.thresholdLimit.toInt()}°C';
                } else if (event.sensorType == 'ph') {
                  reason = 'pH melebihi ${event.thresholdLimit.toStringAsFixed(1)}';
                } else {
                  reason = 'PPM melebihi ${event.thresholdLimit.toInt()}';
                }
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    title: Text(time),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reason),
                        Text(
                          'Suhu: ${event.suhu.toStringAsFixed(1)}°C | pH: ${event.ph.toStringAsFixed(1)} | PPM: ${event.ppm}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}