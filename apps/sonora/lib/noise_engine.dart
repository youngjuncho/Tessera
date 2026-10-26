import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

enum NoiseType {
  white('White noise'),
  pink('Pink noise'),
  brown('Brown noise');

  const NoiseType(this.label);
  final String label;
}

class NoiseEngine {
  static const int _sampleRate = 24000;
  static const int _durationSeconds = 20;

  final SoLoud _player = SoLoud.instance;

  AudioSource? _source;
  SoundHandle? _handle;
  bool _initialized = false;
  double _volume = 0.25;

  bool get isPlaying => _handle != null;
  double get volume => _volume;

  Future<void> initialize() async {
    if (_initialized) return;

    await _player.init(sampleRate: _sampleRate, channels: Channels.mono);
    _initialized = true;
  }

  Future<void> play(NoiseType type) async {
    await initialize();
    await stop();

    final samples = _generate(type);
    final pcm = samples.buffer.asUint8List(
      samples.offsetInBytes,
      samples.lengthInBytes,
    );

    final source = _player.setBufferStream(
      maxBufferSizeBytes: 2 * 1024 * 1024,
      sampleRate: _sampleRate,
      channels: Channels.mono,
      format: BufferType.s16le,
    );

    try {
      const chunkSize = 64 * 1024;

      for (var offset = 0; offset < pcm.length; offset += chunkSize) {
        final end = (offset + chunkSize < pcm.length)
            ? offset + chunkSize
            : pcm.length;

        _player.addAudioDataStream(
          source,
          Uint8List.sublistView(pcm, offset, end),
        );

        if (end < pcm.length) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      _player.setDataIsEnded(source);

      final handle = _player.play(source, looping: true, volume: _volume);

      _source = source;
      _handle = handle;
    } catch (_) {
      await _player.disposeSource(source);
      rethrow;
    }
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0).toDouble();

    final handle = _handle;
    if (handle != null && _player.getIsValidVoiceHandle(handle)) {
      _player.setVolume(handle, _volume);
    }
  }

  Future<void> stop() async {
    final handle = _handle;
    final source = _source;

    _handle = null;
    _source = null;

    if (!_initialized) return;

    if (handle != null) {
      await _player.stop(handle);
    }

    if (source != null) {
      await _player.disposeSource(source);
    }
  }

  Future<void> dispose() async {
    await stop();

    if (_initialized) {
      _player.deinit();
      _initialized = false;
    }
  }

  Int16List _generate(NoiseType type) {
    final count = _sampleRate * _durationSeconds;
    final output = Int16List(count);
    final random = Random();

    double b0 = 0;
    double b1 = 0;
    double b2 = 0;
    double b3 = 0;
    double b4 = 0;
    double b5 = 0;
    double b6 = 0;
    double brown = 0;

    for (var i = 0; i < count; i++) {
      final white = random.nextDouble() * 2 - 1;
      late double sample;

      switch (type) {
        case NoiseType.white:
          sample = white * 0.20;

        case NoiseType.pink:
          b0 = 0.99886 * b0 + white * 0.0555179;
          b1 = 0.99332 * b1 + white * 0.0750759;
          b2 = 0.96900 * b2 + white * 0.1538520;
          b3 = 0.86650 * b3 + white * 0.3104856;
          b4 = 0.55000 * b4 + white * 0.5329522;
          b5 = -0.7616 * b5 - white * 0.0168980;

          final pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362;
          b6 = white * 0.115926;
          sample = pink * 0.08;

        case NoiseType.brown:
          brown = (brown + white * 0.02).clamp(-1.0, 1.0);
          sample = brown * 0.35;
      }

      final scaled = (sample * 32767).round().clamp(-32768, 32767);
      output[i] = scaled;
    }

    return output;
  }
}
