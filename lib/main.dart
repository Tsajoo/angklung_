import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Audio service – one AudioPlayer per note, reused to prevent memory leaks
// ---------------------------------------------------------------------------
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final Map<String, AudioPlayer> _players = {};

  static const Map<String, String> _noteFiles = {
    'C': 'C',
    'D': 'D',
    'E': 'E',
    'F': 'F',
    'G': 'G',
    'A': 'A',
    'B': 'B',
    "C'": 'C2',
  };

  Future<void> play(String note) async {
    final filename = _noteFiles[note];
    if (filename == null) return;
    final player = _players.putIfAbsent(note, () => AudioPlayer());
    await player.stop();
    await player.play(AssetSource('notes/$filename.mp3'));
  }

  Future<void> stopAll() async {
    for (final p in _players.values) {
      await p.stop();
    }
  }

  Future<void> disposeAll() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
  }
}

// ---------------------------------------------------------------------------
// App entry
// ---------------------------------------------------------------------------
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const AngklungApp());
}

class AngklungApp extends StatelessWidget {
  const AngklungApp({super.key});

  @override
  Widget build(BuildContext context) {
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
// Setup gate – checks Firebase URL is set
// ---------------------------------------------------------------------------
class SetupGate extends StatefulWidget {
  const SetupGate({super.key});
  @override
  State<SetupGate> createState() => _SetupGateState();
}

class _SetupGateState extends State<SetupGate> {
  bool? _configured;

  @override
  void initState() {
    super.initState();
    _checkConfig();
  }

  Future<void> _checkConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('firebase_db_url') ?? '';
    setState(() => _configured = url.isNotEmpty);
  }

  void _onConfigured() => setState(() => _configured = true);

  @override
  Widget build(BuildContext context) {
    if (_configured == null) return const SizedBox.shrink();
    if (!_configured!) return SetupScreen(onDone: _onConfigured);
    return const MainPage();
  }
}

// ---------------------------------------------------------------------------
// Setup / Settings screen – Firebase URL + Anthropic API key
// ---------------------------------------------------------------------------
class SetupScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SetupScreen({super.key, required this.onDone});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _fbController = TextEditingController();
  final _aiController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _fbController.text = prefs.getString('firebase_db_url') ?? '';
    _aiController.text = prefs.getString('anthropic_api_key') ?? '';
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('firebase_db_url', _fbController.text.trim());
      await prefs.setString('anthropic_api_key', _aiController.text.trim());
      widget.onDone();
    }
  }

  @override
  void dispose() {
    _fbController.dispose();
    _aiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.music_note, size: 42, color: Color(0xFFAD1457)),
                  const SizedBox(height: 8),
                  const Text(
                    'Angklung IoT',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Configure your connections',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _fbController,
                    decoration: const InputDecoration(
                      labelText: 'Firebase Realtime Database URL *',
                      hintText: 'https://your-project.firebaseio.com',
                      prefixIcon: Icon(Icons.cloud_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _aiController,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      labelText: 'Anthropic API Key (for Song Converter)',
                      hintText: 'sk-ant-...',
                      prefixIcon: const Icon(Icons.auto_awesome_outlined),
                      helperText: 'Optional – needed for YouTube → Sequence conversion',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscureKey ? Icons.visibility_off : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Save & Continue'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 44),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main navigation – 5 tabs
// ---------------------------------------------------------------------------
class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _pageIndex = 0;

  static const _pages = [
    AngklungSimulator(),
    RemoteController(),
    MusicPage(),
    RecorderPage(),
    SongConverterPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 34,
        title: const Text('Angklung IoT', style: TextStyle(fontSize: 13)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 18),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SetupScreen(onDone: () => Navigator.pop(context)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(index: _pageIndex, children: _pages),
      ),
      bottomNavigationBar: NavigationBar(
        height: 54,
        selectedIndex: _pageIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          if (_pageIndex == 0 && i != 0) {
            AudioService.instance.stopAll();
          }
          setState(() => _pageIndex = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.piano_outlined),
            selectedIcon: Icon(Icons.piano),
            label: 'Simulator',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_remote_outlined),
            selectedIcon: Icon(Icons.settings_remote),
            label: 'Remote',
          ),
          NavigationDestination(
            icon: Icon(Icons.music_note_outlined),
            selectedIcon: Icon(Icons.music_note),
            label: 'Music',
          ),
          NavigationDestination(
            icon: Icon(Icons.fiber_manual_record_outlined),
            selectedIcon: Icon(Icons.fiber_manual_record),
            label: 'Record',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Convert',
          ),
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

Future<String> getAnthropicKey() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('anthropic_api_key') ?? '';
}

/// Maps note label → Firebase key under /angklung/
/// Matches exact keys visible in the Realtime Database console.
const Map<String, String> kNoteFirebaseKeys = {
  'C':  'nota1',  // 🎵 note the 'a' — as shown in your Firebase console
  'D':  'note2',
  'E':  'note3',
  'F':  'note4',
  'G':  'note5',
  'A':  'note6',
  'B':  'note7',
  "C'": 'note8',
};

const List<String> kNotes = ['C', 'D', 'E', 'F', 'G', 'A', 'B', "C'"];

const List<Color> kColors = [
  Color(0xFFF8BBD0), // pink
  Color(0xFFE1BEE7), // lavender
  Color(0xFFBBDEFB), // sky blue
  Color(0xFFC8E6C9), // mint
  Color(0xFFFFF9C4), // lemon
  Color(0xFFFFE0B2), // peach
  Color(0xFFFFCDD2), // salmon
  Color(0xFFD1C4E9), // lilac
];

// ---------------------------------------------------------------------------
// Note button – fills its parent; supports tap or press/release
// ---------------------------------------------------------------------------
class NoteButton extends StatefulWidget {
  final String note;
  final Color color;
  final VoidCallback? onTap;
  final void Function(bool pressed)? onPressedChanged;

  const NoteButton({
    super.key,
    required this.note,
    required this.color,
    this.onTap,
    this.onPressedChanged,
  });

  @override
  State<NoteButton> createState() => _NoteButtonState();
}

class _NoteButtonState extends State<NoteButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pressedColor = HSLColor.fromColor(widget.color)
        .withLightness(
          (HSLColor.fromColor(widget.color).lightness - 0.12).clamp(0.0, 1.0),
        )
        .toColor();

    final button = AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      decoration: BoxDecoration(
        color: _pressed ? pressedColor : widget.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _pressed
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Center(
        child: Text(
          widget.note,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5D4037),
          ),
        ),
      ),
    );

    if (widget.onPressedChanged != null) {
      return GestureDetector(
        onTapDown: (_) {
          setState(() => _pressed = true);
          widget.onPressedChanged?.call(true);
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressedChanged?.call(false);
        },
        onTapCancel: () {
          setState(() => _pressed = false);
          widget.onPressedChanged?.call(false);
        },
        child: button,
      );
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: button,
    );
  }
}

// ---------------------------------------------------------------------------
// Note grid – 2 rows × 4
// ---------------------------------------------------------------------------
class NoteGrid extends StatelessWidget {
  final void Function(String note)? onTap;
  final void Function(String note, bool pressed)? onPressedChanged;

  const NoteGrid({super.key, this.onTap, this.onPressedChanged});

  @override
  Widget build(BuildContext context) {
    final topRow = kNotes.sublist(0, 4);
    final bottomRow = kNotes.sublist(4);

    Widget buildRow(List<String> rowNotes, int colorOffset) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rowNotes.asMap().entries.map((e) {
          final note = e.value;
          final color = kColors[e.key + colorOffset];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: NoteButton(
                note: note,
                color: color,
                onTap: onTap != null ? () => onTap!(note) : null,
                onPressedChanged: onPressedChanged != null
                    ? (p) => onPressedChanged!(note, p)
                    : null,
              ),
            ),
          );
        }).toList(),
      );
    }

    return Column(
      children: [
        Expanded(child: buildRow(topRow, 0)),
        const SizedBox(height: 10),
        Expanded(child: buildRow(bottomRow, 4)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 1. SIMULATOR – tap to play sound locally
// ---------------------------------------------------------------------------
class AngklungSimulator extends StatefulWidget {
  const AngklungSimulator({super.key});
  @override
  State<AngklungSimulator> createState() => _AngklungSimulatorState();
}

class _AngklungSimulatorState extends State<AngklungSimulator> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: NoteGrid(
        onTap: (note) => AudioService.instance.play(note),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. REMOTE – sets angklung/nota1…note8 = true in Firebase
//    (ESP32 resets to false after receiving)
// ---------------------------------------------------------------------------
class RemoteController extends StatefulWidget {
  const RemoteController({super.key});
  @override
  State<RemoteController> createState() => _RemoteControllerState();
}

class _RemoteControllerState extends State<RemoteController> {
  String? _lastSent;
  bool _sending = false;

  Future<void> _sendNote(String note) async {
    // Prevent spamming while a request is in flight
    if (_sending) return;
    setState(() {
      _sending = true;
      _lastSent = note;
    });

    try {
      final baseUrl = await getDatabaseUrl();
      if (baseUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Firebase URL not configured')),
          );
        }
        return;
      }

      final firebaseKey = kNoteFirebaseKeys[note]!;
      // PUT true → triggers ESP32 to play this note
      await http.put(
        Uri.parse('$baseUrl/angklung/$firebaseKey.json'),
        headers: {'Content-Type': 'application/json'},
        body: 'true',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Status bar
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.settings_remote, size: 16, color: Color(0xFFAD1457)),
              const SizedBox(width: 6),
              const Text(
                'Remote → ESP32',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 10),
              if (_sending)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (_lastSent != null && !_sending) ...[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    key: ValueKey(_lastSent),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8BBD0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '✓ Sent: $_lastSent  →  ${kNoteFirebaseKeys[_lastSent!]}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                'Sets true → ESP32 resets',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        // Note grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: NoteGrid(onTap: _sendNote),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. MUSIC PAGE – one-tap play for predefined songs + stop
// ---------------------------------------------------------------------------
class MusicPage extends StatefulWidget {
  const MusicPage({super.key});
  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  String? _activeSong;
  bool _sending = false;

  // Predefined songs – key matches exact Firebase field name
  static const List<Map<String, dynamic>> _songs = [
    {
      'key': 'playPusaka',
      'label': 'Pusaka',
      'subtitle': 'Tanah Airku',
      'emoji': '🇮🇩',
      'color': Color(0xFFFFCDD2),
    },
    {
      'key': 'playRaya',
      'label': 'Raya',
      'subtitle': 'Indonesia Raya',
      'emoji': '🎌',
      'color': Color(0xFFF8BBD0),
    },
    {
      'key': 'playHalo',
      'label': 'Halo-Halo',
      'subtitle': 'Halo-Halo Bandung',
      'emoji': '🌆',
      'color': Color(0xFFE1BEE7),
    },
    {
      'key': 'playKartini',
      'label': 'Kartini',
      'subtitle': 'Ibu Kita Kartini',
      'emoji': '👗',
      'color': Color(0xFFBBDEFB),
    },
    {
      'key': 'playKetut',
      'label': 'Ketut',
      'subtitle': 'Custom song',
      'emoji': '🎵',
      'color': Color(0xFFC8E6C9),
    },
  ];

  Future<void> _triggerSong(String songKey) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _activeSong = songKey;
    });

    try {
      final baseUrl = await getDatabaseUrl();
      if (baseUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Firebase URL not configured')),
          );
        }
        return;
      }

      // PUT true to the song key under /angklung/
      await http.put(
        Uri.parse('$baseUrl/angklung/$songKey.json'),
        headers: {'Content-Type': 'application/json'},
        body: 'true',
      );

      final song = _songs.firstWhere((s) => s['key'] == songKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('▶ Playing ${song['label']}…'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _stop() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _activeSong = null;
    });

    try {
      final baseUrl = await getDatabaseUrl();
      if (baseUrl.isEmpty) return;
      await http.put(
        Uri.parse('$baseUrl/angklung/stop.json'),
        headers: {'Content-Type': 'application/json'},
        body: 'true',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('⏹ Stop sent'),
              duration: Duration(seconds: 1)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.music_note, size: 16, color: Color(0xFFAD1457)),
              const SizedBox(width: 6),
              const Text(
                'Play Music on ESP32',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // Stop button
              ElevatedButton.icon(
                onPressed: _sending ? null : _stop,
                icon: const Icon(Icons.stop_circle_outlined, size: 16),
                label: const Text('Stop', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  backgroundColor: Colors.red.shade50,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              if (_sending) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Song cards – 3 columns grid (works well in landscape)
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.8,
              ),
              itemCount: _songs.length,
              itemBuilder: (context, i) {
                final song = _songs[i];
                final key = song['key'] as String;
                final isActive = _activeSong == key;

                return GestureDetector(
                  onTap: _sending ? null : () => _triggerSong(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isActive
                          ? HSLColor.fromColor(song['color'] as Color)
                              .withLightness(0.72)
                              .toColor()
                          : song['color'] as Color,
                      borderRadius: BorderRadius.circular(14),
                      border: isActive
                          ? Border.all(
                              color: Colors.deepOrange.shade400, width: 2)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isActive ? 0.08 : 0.14),
                          blurRadius: isActive ? 2 : 5,
                          offset: Offset(0, isActive ? 1 : 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Text(song['emoji'] as String,
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song['label'] as String,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF5D4037),
                                  ),
                                ),
                                Text(
                                  song['subtitle'] as String,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF8D6E63),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isActive)
                            const Icon(Icons.graphic_eq,
                                size: 16, color: Colors.deepOrange),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. RECORDER – press/release, auto rests, sends [noteIndex, duration] pairs
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
  Timer? _countdownTimer;
  int _elapsedMs = 0;
  int _countdown = 0;

  DateTime? _recordingStartTime;
  DateTime? _lastEventEndTime;

  List<List<dynamic>> _sequence = [];

  String? _pressedNote;
  DateTime? _pressTime;

  static const double _minDurationSec = 0.3;

  void _startCountdown() {
    setState(() => _countdown = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        t.cancel();
        _beginRecording();
      }
    });
  }

  void _beginRecording() {
    final now = DateTime.now();
    setState(() {
      _recording = true;
      _paused = false;
      _elapsedMs = 0;
      _countdown = 0;
      _sequence = [];
      _pressedNote = null;
      _recordingStartTime = now;
      _lastEventEndTime = now;
    });
    _startElapsedTimer();
  }

  void _startElapsedTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_paused && _recordingStartTime != null) {
        setState(() {
          _elapsedMs =
              DateTime.now().difference(_recordingStartTime!).inMilliseconds;
        });
      }
    });
  }

  void _pauseResume() {
    if (_paused) {
      _recordingStartTime =
          DateTime.now().subtract(Duration(milliseconds: _elapsedMs));
      _startElapsedTimer();
      setState(() => _paused = false);
    } else {
      _timer?.cancel();
      setState(() => _paused = true);
    }
  }

  void _reset() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _recording = false;
      _paused = false;
      _elapsedMs = 0;
      _countdown = 0;
      _sequence = [];
      _pressedNote = null;
    });
  }

  Future<void> _stopAndSend() async {
    if (_pressedNote != null) _finaliseCurrentNote();
    _timer?.cancel();
    setState(() {
      _recording = false;
      _paused = false;
    });
    if (_sequence.isEmpty) return;

    final url = await getDatabaseUrl();
    if (url.isNotEmpty) {
      final uri = Uri.parse('$url/recordings.json');
      await http.post(uri, body: jsonEncode(_sequence));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording sent to Firebase')),
        );
      }
    }
  }

  void _onNotePressState(String note, bool pressed) {
    if (!_recording || _paused) {
      if (pressed) AudioService.instance.play(note);
      return;
    }
    if (pressed) {
      if (_pressedNote != null && _pressedNote != note) {
        _finaliseCurrentNote();
      }
      _pressedNote = note;
      _pressTime = DateTime.now();
      AudioService.instance.play(note);
    } else {
      if (_pressedNote == note) {
        _finaliseCurrentNote();
        _pressedNote = null;
      }
    }
  }

  void _finaliseCurrentNote() {
    if (_pressedNote == null || _pressTime == null) return;
    final noteIndex = kNotes.indexOf(_pressedNote!) + 1;
    final pressTime = _pressTime!;
    final now = DateTime.now();

    double durationSec =
        now.difference(pressTime).inMilliseconds / 1000.0;
    if (durationSec < _minDurationSec) durationSec = _minDurationSec;

    final gapSec =
        pressTime.difference(_lastEventEndTime!).inMilliseconds / 1000.0;
    if (gapSec > 0.01) {
      _sequence.add([0, double.parse(gapSec.toStringAsFixed(2))]);
    }
    _sequence.add([noteIndex, double.parse(durationSec.toStringAsFixed(2))]);
    _lastEventEndTime =
        pressTime.add(Duration(milliseconds: (durationSec * 1000).round()));
    setState(() {});
  }

  String _formatMs(int ms) {
    final sec = ms ~/ 1000;
    final min = sec ~/ 60;
    return '${min.toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCountingDown = _countdown > 0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  isCountingDown ? '$_countdown' : _formatMs(_elapsedMs),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isCountingDown ? 40 : 28,
                    fontWeight: FontWeight.bold,
                    color: _recording && !_paused
                        ? Colors.redAccent
                        : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (!_recording && !isCountingDown)
                _CtrlButton(
                  icon: Icons.fiber_manual_record,
                  label: 'Record',
                  color: Colors.redAccent,
                  onPressed: _startCountdown,
                )
              else if (_recording) ...[
                _CtrlButton(
                  icon: _paused ? Icons.play_arrow : Icons.pause,
                  label: _paused ? 'Resume' : 'Pause',
                  onPressed: _pauseResume,
                ),
                const SizedBox(width: 8),
                _CtrlButton(
                  icon: Icons.refresh,
                  label: 'Reset',
                  onPressed: _reset,
                ),
                const SizedBox(width: 8),
                _CtrlButton(
                  icon: Icons.stop_circle,
                  label: 'Stop & Send',
                  color: Colors.deepOrange,
                  onPressed: _stopAndSend,
                ),
              ],
              const SizedBox(width: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8BBD0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_sequence.length} events',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: NoteGrid(onPressedChanged: _onNotePressState),
          ),
        ),
      ],
    );
  }
}

class _CtrlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const _CtrlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: color,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. SONG CONVERTER – YouTube URL → Claude AI → angklung sequence → Firebase
//
// Sequence format: [[noteIndex, durationSeconds], ...]
//   noteIndex: 0=rest, 1=C, 2=D, 3=E, 4=F, 5=G, 6=A, 7=B, 8=C'
//   durationSeconds: e.g. 0.25, 0.5, 1.0, 2.0
//
// Saved at: songs/<firebaseGeneratedId>/
// ---------------------------------------------------------------------------
class SongConverterPage extends StatefulWidget {
  const SongConverterPage({super.key});
  @override
  State<SongConverterPage> createState() => _SongConverterPageState();
}

class _SongConverterPageState extends State<SongConverterPage> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  bool _converting = false;
  bool _saving = false;
  String? _error;
  String? _statusMessage;
  List<List<dynamic>>? _sequence;
  String? _savedId;

  // ── Call Claude API with web_search tool to identify song + make sequence ──
  Future<void> _convert() async {
    final ytUrl = _urlController.text.trim();
    if (ytUrl.isEmpty) {
      setState(() => _error = 'Please enter a YouTube URL');
      return;
    }

    setState(() {
      _converting = true;
      _error = null;
      _sequence = null;
      _savedId = null;
      _statusMessage = 'Identifying song…';
    });

    try {
      final apiKey = await getAnthropicKey();
      if (apiKey.isEmpty) {
        setState(() {
          _error =
              'Anthropic API key not configured.\nGo to ⚙ Settings and add your sk-ant-... key.';
        });
        return;
      }

      // First call: identify the song + generate sequence
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 2000,
          'tools': [
            {'type': 'web_search_20250305', 'name': 'web_search'}
          ],
          'messages': [
            {
              'role': 'user',
              'content': '''You are an expert angklung music transcriber.

YouTube URL: $ytUrl

Your task:
1. Use web_search to find the song title and artist from this YouTube URL (search the video ID or URL).
2. Look up the melody/notes of this song.
3. Transcribe the MAIN MELODY (verse or chorus) into angklung notation.

Angklung note mapping:
  0 = rest/silence
  1 = C  (Do)
  2 = D  (Re)
  3 = E  (Mi)
  4 = F  (Fa)
  5 = G  (Sol)
  6 = A  (La)
  7 = B  (Si)
  8 = C\' (High Do)

Duration values (in seconds): 0.25, 0.5, 0.75, 1.0, 1.5, 2.0

Rules:
- Only use notes 0–8 (diatonic C major scale)
- Aim for 16 to 60 events
- Include rests (0) where appropriate for rhythm
- Transpose as needed to stay within the 1–8 range

IMPORTANT: Your final response must contain ONLY a valid JSON array.
Do not include any explanation, markdown backticks, or text outside the array.

Format:
[[noteIndex, durationSeconds], [noteIndex, durationSeconds], ...]

Example:
[[3,0.5],[3,0.5],[5,1.0],[3,1.0],[4,0.5],[2,2.0],[0,0.5],[1,0.5],[2,0.5],[3,1.0]]'''
            }
          ],
        }),
      );

      setState(() => _statusMessage = 'Processing response…');

      if (response.statusCode != 200) {
        final errBody = utf8.decode(response.bodyBytes);
        Map<String, dynamic>? errJson;
        try {
          errJson = jsonDecode(errBody) as Map<String, dynamic>;
        } catch (_) {}
        final msg = errJson?['error']?['message'] ?? 'HTTP ${response.statusCode}';
        setState(() => _error = 'API error: $msg');
        return;
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      final content = data['content'] as List<dynamic>;

      // Grab the last text block (comes after any tool_use / tool_result blocks)
      String? rawText;
      for (int i = content.length - 1; i >= 0; i--) {
        final block = content[i] as Map<String, dynamic>;
        if (block['type'] == 'text') {
          rawText = block['text'] as String;
          break;
        }
      }

      if (rawText == null || rawText.isEmpty) {
        setState(() => _error = 'No text response from AI.');
        return;
      }

      // Strip any accidental markdown fences
      final cleaned = rawText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      // Find the JSON array in the response (handles extra text before/after)
      final match = RegExp(r'\[[\s\S]*\]').firstMatch(cleaned);
      if (match == null) {
        setState(() =>
            _error = 'Could not parse JSON array from response:\n\n$rawText');
        return;
      }

      List<List<dynamic>> parsed;
      try {
        final raw = jsonDecode(match.group(0)!) as List<dynamic>;
        parsed = raw
            .map((e) => (e as List<dynamic>)
                .map((v) => v is num ? v : num.parse(v.toString()))
                .toList())
            .toList();
      } catch (e) {
        setState(() => _error = 'JSON parse error: $e\n\n${match.group(0)}');
        return;
      }

      // Auto-fill song name from text before the array (if short enough)
      if (_nameController.text.isEmpty) {
        final before = cleaned.substring(0, match.start).trim();
        if (before.isNotEmpty && before.length < 120) {
          _nameController.text = before
              .replaceAll(RegExp(r'\n+'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
        }
      }

      setState(() {
        _sequence = parsed;
        _statusMessage = null;
      });
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  // ── Save sequence to Firebase at songs/<auto-id> ──────────────────────────
  Future<void> _saveToFirebase() async {
    if (_sequence == null) return;
    setState(() {
      _saving = true;
      _savedId = null;
    });

    try {
      final baseUrl = await getDatabaseUrl();
      if (baseUrl.isEmpty) {
        setState(() => _error = 'Firebase URL not configured');
        return;
      }

      final payload = jsonEncode({
        'name': _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : 'Unknown Song',
        'source': _urlController.text.trim(),
        'sequence': _sequence,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      // POST → Firebase generates a unique push ID (e.g. -NxAbc123)
      final response = await http.post(
        Uri.parse('$baseUrl/songs.json'),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );

      if (response.statusCode == 200) {
        final responseData =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final newId = responseData['name'] as String;
        setState(() => _savedId = newId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Saved as songs/$newId'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() => _error = 'Firebase save failed: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _error = 'Save error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Preview: human-readable note names ────────────────────────────────────
  String _buildPreview(List<List<dynamic>> seq) {
    const noteNames = ['—', 'C', 'D', 'E', 'F', 'G', 'A', 'B', "C'"];
    return seq.map((e) {
      final idx = (e[0] as num).toInt().clamp(0, 8);
      final dur = (e[1] as num).toDouble();
      return '${noteNames[idx]}(${dur}s)';
    }).join('  ');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 16, color: Color(0xFFAD1457)),
              const SizedBox(width: 6),
              const Text(
                'YouTube → Angklung Sequence',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'Saves to  songs/<id>',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── URL input ────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _urlController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'YouTube URL',
                    labelStyle: const TextStyle(fontSize: 13),
                    hintText: 'https://youtube.com/watch?v=...',
                    prefixIcon: const Icon(Icons.link, size: 18),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _nameController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Song name',
                    labelStyle: TextStyle(fontSize: 13),
                    prefixIcon: Icon(Icons.music_note, size: 18),
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _converting ? null : _convert,
                icon: _converting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(
                  _converting ? 'Converting…' : 'Convert',
                  style: const TextStyle(fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),

          // ── Status / Error ───────────────────────────────────────────────
          if (_statusMessage != null && _converting) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text(_statusMessage!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 12, color: Colors.red.shade800),
              ),
            ),
          ],

          // ── Result ───────────────────────────────────────────────────────
          if (_sequence != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8BBD0).withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF8BBD0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 15, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        '${_sequence!.length} events generated',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Total: ${_sequence!.fold<double>(0.0, (sum, e) => sum + (e[1] as num).toDouble()).toStringAsFixed(1)}s',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Human-readable preview
                  Container(
                    constraints: const BoxConstraints(maxHeight: 56),
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _buildPreview(_sequence!),
                        style: const TextStyle(
                            fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Raw JSON
                  Container(
                    constraints: const BoxConstraints(maxHeight: 42),
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        jsonEncode(_sequence),
                        style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: Colors.black54),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Save button ───────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveToFirebase,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_upload, size: 16),
                    label: Text(
                      _saving ? 'Saving…' : 'Save to Firebase  (songs/)',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade50,
                      foregroundColor: Colors.green.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                if (_savedId != null) ...[
                  const SizedBox(width: 10),
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'songs/$_savedId',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}