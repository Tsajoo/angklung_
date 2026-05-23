import 'package:firebase_database/firebase_database.dart';
import '../models/threshold_event.dart';

class FirebaseService {
  final DatabaseReference db = FirebaseDatabase.instance.ref();

  // Sensor paths
  final String suhuPath = 'realtime/suhu';
  final String phPath = 'realtime/ph';
  final String ppmPath = 'realtime/mq';

  // Config paths
  final String suhuThresholdPath = 'config/suhuThreshold';
  final String phThresholdPath = 'config/phThreshold';
  final String ppmThresholdPath = 'config/ppmThreshold';

  // History
  final String historyPath = 'history';

  Stream<double> getSuhuStream() {
    return db.child(suhuPath).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    });
  }

  Stream<double> getPhStream() {
    return db.child(phPath).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    });
  }

  Stream<int> getPpmStream() {
    return db.child(ppmPath).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    });
  }

  Stream<double> getSuhuThresholdStream() {
    return db.child(suhuThresholdPath).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 40.0;
      return 40.0;
    });
  }

  Stream<double> getPhThresholdStream() {
    return db.child(phThresholdPath).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 8.5;
      return 8.5;
    });
  }

  Stream<int> getPpmThresholdStream() {
    return db.child(ppmThresholdPath).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 1000;
      return 1000;
    });
  }

  Future<void> updateSuhuThreshold(double value) async {
    await db.child(suhuThresholdPath).set(value);
  }

  Future<void> updatePhThreshold(double value) async {
    await db.child(phThresholdPath).set(value);
  }

  Future<void> updatePpmThreshold(int value) async {
    await db.child(ppmThresholdPath).set(value);
  }

  Future<void> saveThresholdEvent(ThresholdEvent event) async {
    await db.child(historyPath).push().set(event.toMap());
  }

  Stream<List<ThresholdEvent>> getHistoryStream() {
    return db.child(historyPath).onValue.map((event) {
      final map = event.snapshot.value as Map<dynamic, dynamic>?;
      if (map == null) return <ThresholdEvent>[];
      return map.entries.map((entry) {
        final data = Map<String, dynamic>.from(entry.value);
        return ThresholdEvent.fromMap(entry.key, data);
      }).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }
}