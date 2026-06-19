import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

class DisplayAudio {
  DisplayAudio._();
  static final DisplayAudio instance = DisplayAudio._();

  bool enabled = true;
  bool unlocked = false;

  static const _celebrationAsset =
      'assets/sounds/Crowd Cheering _ Sound Effect.mp3';
  String? _celebrationUrl;

  Future<void> unlock() async {
    unlocked = true;
  }

  Future<void> playCourtReady() async {
    if (!enabled || !unlocked) return;
    const durationSec = 0.48;
    await _playWav(_refereeWhistleWav(durationSec), durationSec, volume: 0.5);
  }

  Future<void> playNextUp() async {
    if (!enabled || !unlocked) return;
    const durationSec = 0.22;
    await _playWav(_attentionTapWav(durationSec), durationSec, volume: 0.42);
  }

  Future<void> playCelebration() async {
    if (!enabled || !unlocked) return;
    // Big stadium cheer — trimmed so winner announcements follow promptly.
    await _playCelebrationAsset();
  }

  Future<void> _playCelebrationAsset() async {
    _celebrationUrl ??= await _loadAssetObjectUrl(
      _celebrationAsset,
      'audio/mpeg',
    );
    await _playUrl(
      _celebrationUrl!,
      volume: 0.88,
      maxDurationSec: 6.5,
    );
  }

  Future<String> _loadAssetObjectUrl(String assetPath, String mimeType) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final blob = html.Blob([bytes], mimeType);
    return html.Url.createObjectUrlFromBlob(blob);
  }

  Future<void> _playUrl(
    String url, {
    required double volume,
    double? maxDurationSec,
  }) async {
    final audio = html.AudioElement()
      ..src = url
      ..volume = volume;

    final completer = Completer<void>();
    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    if (maxDurationSec != null) {
      audio.onTimeUpdate.listen((_) {
        if (audio.currentTime >= maxDurationSec) {
          audio.pause();
          finish();
        }
      });
    }

    audio.onEnded.listen((_) => finish());
    audio.onError.listen((_) => finish());

    await audio.play().catchError((_) => finish());

    final timeoutMs = ((maxDurationSec ?? 30) * 1000).ceil() + 800;
    await completer.future.timeout(
      Duration(milliseconds: timeoutMs),
      onTimeout: finish,
    );
  }

  Future<void> _playWav(
    Uint8List bytes,
    double durationSec, {
    double volume = 0.65,
  }) async {
    final blob = html.Blob([bytes], 'audio/wav');
    final url = html.Url.createObjectUrlFromBlob(blob);
    await _playUrl(url, volume: volume, maxDurationSec: durationSec);
    html.Url.revokeObjectUrl(url);
  }

  Uint8List _refereeWhistleWav(double durationSec) {
    const sampleRate = 44100;
    final sampleCount = (sampleRate * durationSec).round();
    final samples = List<double>.filled(sampleCount, 0);
    final rng = _Rng(771_023);
    const baseFreq = 3150.0;

    for (var i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      final attack = (t < 0.04) ? t / 0.04 : 1.0;
      final release = t > durationSec - 0.12
          ? (durationSec - t) / 0.12
          : 1.0;
      final env = attack * release;

      final wobble = 1 + 0.012 * _sin(2 * math.pi * 6.5 * t);
      final freq = baseFreq * wobble;
      final tone = _sin(2 * math.pi * freq * t) * 0.55 +
          _sin(2 * math.pi * freq * 2.01 * t) * 0.18;
      final breath = rng.nextSigned() * 0.08;

      samples[i] = (tone + breath) * env * 0.42;
    }

    return _samplesToWav(samples, sampleRate);
  }

  Uint8List _attentionTapWav(double durationSec) {
    const sampleRate = 44100;
    final sampleCount = (sampleRate * durationSec).round();
    final samples = List<double>.filled(sampleCount, 0);
    final rng = _Rng(119_337);

    const taps = [0.0, 0.11];
    for (final start in taps) {
      final startSample = (start * sampleRate).round();
      const tapLen = 0.018;
      final tapSamples = (tapLen * sampleRate).round();
      for (var i = 0; i < tapSamples; i++) {
        final idx = startSample + i;
        if (idx < 0 || idx >= samples.length) break;
        final t = i / sampleRate;
        final env = math.exp(-t * 120);
        final noise = rng.nextSigned();
        final knock = _sin(2 * math.pi * 420 * t) * (1 - t / tapLen);
        samples[idx] += (noise * 0.55 + knock * 0.45) * env * 0.35;
      }
    }

    return _samplesToWav(samples, sampleRate);
  }

  Uint8List _samplesToWav(List<double> samples, int sampleRate) {
    var peak = 0.0;
    for (final sample in samples) {
      final abs = sample.abs();
      if (abs > peak) peak = abs;
    }
    final gain = peak > 0 ? 0.88 / peak : 1.0;

    final dataSize = samples.length * 2;
    final buffer = ByteData(44 + dataSize);

    void writeString(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        buffer.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    writeString(0, 'RIFF');
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);
    buffer.setUint16(22, 1, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little);
    buffer.setUint16(32, 2, Endian.little);
    buffer.setUint16(34, 16, Endian.little);
    writeString(36, 'data');
    buffer.setUint32(40, dataSize, Endian.little);

    for (var i = 0; i < samples.length; i++) {
      final scaled = (samples[i] * gain * 32767).round().clamp(-32767, 32767);
      buffer.setInt16(44 + i * 2, scaled, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  double _sin(double x) {
    x = x % (2 * math.pi);
    final x2 = x * x;
    return x * (1 - x2 / 6 + x2 * x2 / 120);
  }
}

class _Rng {
  _Rng(this._seed);

  int _seed;

  double next() {
    _seed = (_seed * 1664525 + 1013904223) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }

  double nextSigned() => next() * 2 - 1;
}
