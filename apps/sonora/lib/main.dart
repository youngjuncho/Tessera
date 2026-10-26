import 'dart:async';

import 'package:flutter/material.dart';

import 'noise_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SonoraApp());
}

class SonoraApp extends StatelessWidget {
  const SonoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sonora',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF668C83),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101916),
        useMaterial3: true,
      ),
      home: const SonoraHomePage(),
    );
  }
}

class SonoraHomePage extends StatefulWidget {
  const SonoraHomePage({super.key});

  @override
  State<SonoraHomePage> createState() => _SonoraHomePageState();
}

class _SonoraHomePageState extends State<SonoraHomePage> {
  final NoiseEngine _engine = NoiseEngine();

  NoiseType _selected = NoiseType.pink;
  double _volume = 0.25;
  bool _ready = false;
  bool _playing = false;
  bool _busy = true;
  String? _error;

  int _sleepMinutes = 0;
  int _fadeMinutes = 5;

  Timer? _sleepTimer;
  Timer? _fadeStartTimer;
  Timer? _fadeTimer;

  DateTime? _fadeStartedAt;
  Duration _fadeDuration = Duration.zero;
  double _fadeFactor = 1.0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _engine.initialize();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '오디오 초기화 실패: $error';
      });
    }
  }

  Future<void> _playSelected() async {
    if (!_ready || _busy) return;

    final wasPlaying = _playing;
    setState(() {
      _playing = true;
      _busy = true;
    });

    if (!wasPlaying) {
      _startSleepTimer();
    }

    try {
      await _engine.play(_selected);
      if (!mounted) return;
      setState(() {
        _playing = true;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _busy = false;
        _error = '재생 실패: $error';
      });
    }
  }

  Future<void> _stop({bool force = false}) async {
    if (_busy && !force) return;

    _cancelSleepTimers();

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _engine.stop();
      if (!mounted) return;

      setState(() {
        _playing = false;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _busy = false;
        _error = '정지 실패: $error';
      });
    }
  }

  void _cancelSleepTimers() {
    _sleepTimer?.cancel();
    _fadeStartTimer?.cancel();
    _fadeTimer?.cancel();

    _sleepTimer = null;
    _fadeStartTimer = null;
    _fadeTimer = null;
    _fadeStartedAt = null;
    _fadeDuration = Duration.zero;
    _fadeFactor = 1.0;
  }

  void _startSleepTimer() {
    _cancelSleepTimers();

    if (_sleepMinutes <= 0) return;

    final totalDuration = Duration(minutes: _sleepMinutes);
    final requestedFade = Duration(minutes: _fadeMinutes);
    final fadeDuration = _fadeMinutes <= 0
        ? Duration.zero
        : requestedFade <= totalDuration
        ? requestedFade
        : totalDuration;

    _sleepTimer = Timer(totalDuration, () {
      unawaited(_stop(force: true));
    });

    if (fadeDuration == Duration.zero) return;

    final fadeDelay = totalDuration - fadeDuration;

    _fadeStartTimer = Timer(fadeDelay, () {
      _fadeStartedAt = DateTime.now();
      _fadeDuration = fadeDuration;

      _fadeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        final startedAt = _fadeStartedAt;
        if (startedAt == null) {
          timer.cancel();
          return;
        }

        final elapsed = DateTime.now().difference(startedAt);
        final progress = elapsed.inMilliseconds / _fadeDuration.inMilliseconds;

        _fadeFactor = (1.0 - progress).clamp(0.0, 1.0);
        _engine.setVolume(_volume * _fadeFactor);

        if (_fadeFactor <= 0) {
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _cancelSleepTimers();
    unawaited(_engine.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sonora'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.graphic_eq_rounded,
                size: 76,
                color: Color(0xFF9BC8B8),
              ),
              const SizedBox(height: 20),
              const Text(
                'Find your quiet',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _playing ? '재생 중 · ${_selected.label}' : '원하는 소리를 선택하세요',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 32),
              for (final type in NoiseType.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() => _selected = type);
                            if (_playing) {
                              _playSelected();
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: _selected == type
                          ? const Color(0xFF29483F)
                          : Colors.transparent,
                      side: BorderSide(
                        color: _selected == type
                            ? const Color(0xFF9BC8B8)
                            : Colors.white24,
                      ),
                    ),
                    child: Text(type.label),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.volume_down_rounded),
                  Expanded(
                    child: Slider(
                      value: _volume,
                      min: 0,
                      max: 1,
                      onChanged: (value) {
                        setState(() => _volume = value);
                        _engine.setVolume(value * _fadeFactor);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${(_volume * 100).round()}%',
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('수면 타이머')),
                  DropdownButton<int>(
                    value: _sleepMinutes,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('끔')),
                      DropdownMenuItem(value: 1, child: Text('1분 (테스트)')),
                      DropdownMenuItem(value: 30, child: Text('30분')),
                      DropdownMenuItem(value: 60, child: Text('1시간')),
                      DropdownMenuItem(value: 120, child: Text('2시간')),
                      DropdownMenuItem(value: 240, child: Text('4시간')),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _sleepMinutes = value);
                            if (_playing) _startSleepTimer();
                          },
                  ),
                ],
              ),
              Row(
                children: [
                  const Expanded(child: Text('페이드아웃')),
                  DropdownButton<int>(
                    value: _fadeMinutes,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('끔')),
                      DropdownMenuItem(value: 1, child: Text('1분')),
                      DropdownMenuItem(value: 5, child: Text('5분')),
                      DropdownMenuItem(value: 10, child: Text('10분')),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _fadeMinutes = value);
                            if (_playing) _startSleepTimer();
                          },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: !_ready || _busy
                    ? null
                    : (_playing ? _stop : _playSelected),
                icon: Icon(
                  _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(_busy ? '준비 중...' : (_playing ? '정지' : '재생')),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const Spacer(),
              const Text(
                'Sleep · Focus · Relax',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
