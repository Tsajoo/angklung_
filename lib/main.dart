import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const AngklungApp());

class AngklungApp extends StatelessWidget {
  const AngklungApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Force landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    return MaterialApp(
      title: 'Angklung IoT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF8BBD0),
          brightness: Brightness.light,
        ),
      ),
      home: const SetupGate(),
    );
  }
}

// ---------------------------------------------------------------------------
// Setup gate – first‑time Firebase URL entry
// ---------------------------------------------------------------------------
class SetupGate extends StatefulWidget {
  const SetupGate({super.key});
  @override
  State<SetupGate> createState() => _SetupGateState();
}

class _SetupGateState extends State<SetupGate> {
  bool? configured;

  @override
  void initState() {
    super.initState();
    _checkConfig();
  }

  Future<void> _checkConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('firebase_db_url') ?? '';
    setState(() => configured = url.isNotEmpty);
  }

  void _onConfigured() => setState(() => configured = true);

  @override
  Widget build(BuildContext context) {
    if (configured == null) return const SizedBox.shrink();
    if (!configured!) return SetupScreen(onDone: _onConfigured);
    return const MainPage();
  }
}

class SetupScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SetupScreen({super.key, required this.onDone});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('firebase_db_url', _controller.text.trim());
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Welcome to Angklung IoT',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Firebase Realtime Database URL',
                    hintText: 'https://your-project.firebaseio.com',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save & Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main navigation (3 pages)
// ---------------------------------------------------------------------------
class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _pageIndex = 0;

  static const pages = [
    AngklungSimulator(),
    RemoteController(),
    RecorderPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _pageIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pageIndex,
        onDestinationSelected: (i) => setState(() => _pageIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.music_note), label: 'Simulator'),
          NavigationDestination(icon: Icon(Icons.settings_remote), label: 'Remote'),
          NavigationDestination(
              icon: Icon(Icons.fiber_manual_record), label: 'Record'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
Future<String> getDatabaseUrl() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('firebase_db_url') ?? '';
}

// ---------------------------------------------------------------------------
// 1. SIMULATOR – 8 notes (C‑C'), tap to play sound
// ---------------------------------------------------------------------------
class AngklungSimulator extends StatelessWidget {
  const AngklungSimulator({super.key});

  static const notes = ['C', 'D', 'E', 'F', 'G', 'A', 'B', "C'"];
  static const colors = [
    Color(0xFFF8BBD0), // pink
    Color(0xFFE1BEE7), // lavender
    Color(0xFFBBDEFB), // light blue
    Color(0xFFC8E6C9), // mint
    Color(0xFFFFF9C4), // lemon
    Color(0xFFFFE0B2), // peach
    Color(0xFFFFCDD2), // salmon
    Color(0xFFD1C4E9), // lilac
  ];

  Future<void> _playNote(BuildContext context, String note) async {
    final player = AudioPlayer();
    await player.play(AssetSource('notes/$note.wav'));
  }

  @override
  Widget build(BuildContext context) {
    final topRow = notes.sublist(0, 4);
    final bottomRow = notes.sublist(4);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: topRow
              .asMap()
              .entries
              .map((e) => NoteButton(
                    note: e.value,
                    color: colors[e.key],
                    onTap: () => _playNote(context, e.value),
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: bottomRow
              .asMap()
              .entries
              .map((e) => NoteButton(
                    note: e.value,
                    color: colors[e.key + 4],
                    onTap: () => _playNote(context, e.value),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Note button widget (supports simple tap or press/release)
// ---------------------------------------------------------------------------
class NoteButton extends StatelessWidget {
  final String note;
  final Color color;
  final VoidCallback? onTap;
  final Function(bool)? onPressedChanged; // true = pressed, false = released

  const NoteButton({
    super.key,
    required this.note,
    required this.color,
    this.onTap,
    this.onPressedChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      child: SizedBox(
        width: 80,
        height: 120,
        child: Center(
          child: Text(
            note,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );

    if (onPressedChanged != null) {
      return GestureDetector(
        onTapDown: (_) => onPressedChanged?.call(true),
        onTapUp: (_) => onPressedChanged?.call(false),
        onTapCancel: () => onPressedChanged?.call(false),
        child: button,
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: button,
    );
  }
}

// ---------------------------------------------------------------------------
// 2. REMOTE – tap sends note to Firebase (for ESP32)
// ---------------------------------------------------------------------------
class RemoteController extends StatelessWidget {
  const RemoteController({super.key});

  Future<void> _sendNote(String note) async {
    final url = await getDatabaseUrl();
    if (url.isEmpty) return;
    final uri = Uri.parse('$url/play/note.json');
    await http.put(uri,
        body: jsonEncode(
            {'note': note, 'timestamp': DateTime.now().millisecondsSinceEpoch}));
  }

  @override
  Widget build(BuildContext context) {
    final notes = AngklungSimulator.notes;
    final colors = AngklungSimulator.colors;

    return Column(
      children: [
        const SizedBox(height: 10),
        const Text('Remote (ESP32)', style: TextStyle(fontSize: 18)),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: notes
              .sublist(0, 4)
              .asMap()
              .entries
              .map((e) => NoteButton(
                    note: e.value,
                    color: colors[e.key],
                    onTap: () => _sendNote(e.value),
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: notes
              .sublist(4)
              .asMap()
              .entries
              .map((e) => NoteButton(
                    note: e.value,
                    color: colors[e.key + 4],
                    onTap: () => _sendNote(e.value),
                  ))
              .toList(),
        ),
        const Spacer(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. RECORDER – press & release, min duration 0.3s, auto‑rests, format [note,dur]
// ---------------------------------------------------------------------------
class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key});
  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  bool _recording = false;
  bool _paused = false;
  Timer? _timer;
  int _elapsedMs = 0;               // total recording time (ms)
  int _countdown = 0;               // 3‑2‑1 before start
  DateTime? _recordingStartTime;    // when recording really started

  // Sequence of [noteIndex, duration] pairs (index 0 = rest, 1‑8 = notes)
  List<List<dynamic>> _sequence = [];

  // Currently held note info
  String? _pressedNote;             // note name
  DateTime? _pressTime;             // when the current note was pressed

  // Last end time (used to calculate rests)
  DateTime? _lastEventEndTime;      // end of last note/rest

  final notes = AngklungSimulator.notes;
  final colors = AngklungSimulator.colors;

  static const double minDurationSec = 0.3;

  void _startCountdown() {
    _countdown = 3;
    setState(() {});
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown > 1) {
        _countdown--;
        setState(() {});
      } else {
        t.cancel();
        _beginRecording();
      }
    });
  }

  void _beginRecording() {
    _recording = true;
    _paused = false;
    _elapsedMs = 0;
    _sequence = [];
    _pressedNote = null;
    _recordingStartTime = DateTime.now();
    _lastEventEndTime = _recordingStartTime;  // start of silence

    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!_paused) {
        _elapsedMs = DateTime.now().difference(_recordingStartTime!).inMilliseconds;
        setState(() {});
      }
    });
    setState(() {});
  }

  void _pauseResume() {
    if (_paused) {
      // Resume
      final now = DateTime.now();
      // Adjust start so elapsed stays continuous
      _recordingStartTime = now.subtract(Duration(milliseconds: _elapsedMs));
      // We don't change _lastEventEndTime – gaps are computed relative to absolute times
      _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
        _elapsedMs = DateTime.now().difference(_recordingStartTime!).inMilliseconds;
        setState(() {});
      });
      _paused = false;
    } else {
      // Pause
      _paused = true;
      _timer?.cancel();
    }
    setState(() {});
  }

  void _reset() {
    _timer?.cancel();
    _recording = false;
    _paused = false;
    _elapsedMs = 0;
    _countdown = 0;
    _sequence = [];
    _pressedNote = null;
    setState(() {});
  }

  void _stopAndSend() async {
    // If a note is still pressed, finalise it
    if (_pressedNote != null) {
      _finaliseCurrentNote();
    }

    _timer?.cancel();
    _recording = false;
    setState(() {});

    final url = await getDatabaseUrl();
    if (url.isNotEmpty && _sequence.isNotEmpty) {
      final uri = Uri.parse('$url/recordings.json');
      await http.post(uri, body: jsonEncode(_sequence));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording sent to Firebase')),
        );
      }
    }
  }

  // Called when a note button is pressed or released
  void _onNotePressState(String note, bool pressed) {
    if (!_recording || _paused) {
      // In non‑recording mode, just play the sound
      if (pressed) {
        AudioPlayer().play(AssetSource('notes/$note.wav'));
      }
      return;
    }

    if (pressed) {
      // If another note is still held, finalise it first
      if (_pressedNote != null && _pressedNote != note) {
        _finaliseCurrentNote();
      }
      _pressedNote = note;
      _pressTime = DateTime.now();
    } else {
      // Released the same note
      if (_pressedNote == note) {
        _finaliseCurrentNote();
        _pressedNote = null;
      }
    }
  }

  // Converts the currently held note into a recorded entry, adding rest before it
  void _finaliseCurrentNote() {
    if (_pressedNote == null || _pressTime == null) return;

    final noteIndex = notes.indexOf(_pressedNote!) + 1; // 1‑8
    final pressTime = _pressTime!;
    final now = DateTime.now();
    double durationSec = (now.difference(pressTime).inMilliseconds) / 1000.0;
    if (durationSec < minDurationSec) durationSec = minDurationSec;

    // Calculate gap between last event end and this note's press
    final gapSec = (pressTime.difference(_lastEventEndTime!).inMilliseconds) / 1000.0;
    if (gapSec > 0.01) {
      // Insert a rest (note 0) of that duration
      _sequence.add([0, double.parse(gapSec.toStringAsFixed(2))]);
    }

    // Add the actual note
    _sequence.add([noteIndex, double.parse(durationSec.toStringAsFixed(2))]);

    // Update last event end time to when this note finishes
    _lastEventEndTime = pressTime.add(Duration(milliseconds: (durationSec * 1000).round()));
  }

  String _formatMs(int ms) {
    final sec = (ms / 1000).floor();
    final min = (sec / 60).floor();
    final remainSec = sec % 60;
    return '${min.toString().padLeft(2, '0')}:${remainSec.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        // Timer display
        Text(
          _countdown > 0
              ? 'Starting in $_countdown...'
              : _formatMs(_elapsedMs),
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
        ),
        // Recording controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_recording)
              ElevatedButton.icon(
                onPressed: _startCountdown,
                icon: const Icon(Icons.fiber_manual_record, color: Colors.red),
                label: const Text('Record'),
              )
            else ...[
              ElevatedButton.icon(
                onPressed: _pauseResume,
                icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                label: Text(_paused ? 'Resume' : 'Pause'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _stopAndSend,
                icon: const Icon(Icons.stop),
                label: const Text('Stop & Send'),
              ),
            ],
          ],
        ),
        const Spacer(),
        // Top row of notes (C D E F)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: notes
              .sublist(0, 4)
              .asMap()
              .entries
              .map((e) => NoteButton(
                    note: e.value,
                    color: colors[e.key],
                    onPressedChanged: (pressed) =>
                        _onNotePressState(e.value, pressed),
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),
        // Bottom row (G A B C')
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: notes
              .sublist(4)
              .asMap()
              .entries
              .map((e) => NoteButton(
                    note: e.value,
                    color: colors[e.key + 4],
                    onPressedChanged: (pressed) =>
                        _onNotePressState(e.value, pressed),
                  ))
              .toList(),
        ),
        const Spacer(),
        Text('Recorded events: ${_sequence.length}'),
        const SizedBox(height: 10),
      ],
    );
  }
}