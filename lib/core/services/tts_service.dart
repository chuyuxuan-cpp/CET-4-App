import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_tts/flutter_tts.dart';

/// A user-safe failure raised by [TtsService].
class TtsException implements Exception {
  final String message;
  final Object? cause;

  const TtsException(this.message, {this.cause});

  @override
  String toString() => message;
}

/// Provides on-device English text-to-speech playback.
class TtsService {
  TtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  Future<void>? _initialization;
  TtsException? _playbackError;
  bool _disposed = false;

  /// Configures the speech engine. Calling this more than once is safe.
  Future<void> initialize() {
    if (_disposed) {
      return Future<void>.error(const TtsException('语音服务已关闭。'));
    }
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      _tts.setErrorHandler(_handleError);
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-US');

      final voices = await _tts.getVoices;
      final fallback = _findEnglishVoice(voices);
      if (fallback != null) {
        await _tts.setVoice(fallback);
      }

      if (Platform.isIOS) {
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          const <IosTextToSpeechAudioCategoryOptions>[],
          IosTextToSpeechAudioMode.spokenAudio,
        );
      }
    } catch (error, stackTrace) {
      _initialization = null;
      throw _toTtsException(error, stackTrace);
    }
  }

  /// Speaks [text], stopping any previous utterance first.
  Future<void> speak(String text) async {
    if (_disposed) throw const TtsException('语音服务已关闭。');
    final phrase = text.trim();
    if (phrase.isEmpty) return;

    await initialize();
    try {
      _playbackError = null;
      await _tts.stop();
      final result = await _tts.speak(phrase);
      final playbackError = _playbackError;
      if (playbackError != null) throw playbackError;
      if (!_speakSucceeded(result)) {
        throw TtsException('语音播放失败。', cause: result);
      }
    } catch (error, stackTrace) {
      throw _toTtsException(error, stackTrace);
    }
  }

  /// Stops the current utterance, if any.
  Future<void> stop() async {
    if (_disposed) return;
    try {
      await _tts.stop();
    } catch (error, stackTrace) {
      throw _toTtsException(error, stackTrace);
    }
  }

  /// Stops playback and releases the service for future calls.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _tts.stop();
    } catch (_) {
      // Disposal must remain safe even if the platform engine is unavailable.
    }
  }

  void _handleError(dynamic message) {
    _playbackError = TtsException('语音播放不可用，请稍后重试。', cause: message);
  }

  static Map<String, String>? _findEnglishVoice(dynamic voices) {
    if (voices is! List) return null;
    for (final voice in voices) {
      if (voice is! Map) continue;
      final locale = voice['locale']?.toString().toLowerCase();
      if (locale != null && (locale == 'en-us' || locale.startsWith('en-'))) {
        return <String, String>{
          for (final entry in voice.entries)
            if (entry.key != null && entry.value != null)
              entry.key.toString(): entry.value.toString(),
        };
      }
    }
    return null;
  }

  static bool _speakSucceeded(dynamic result) =>
      (result is num && result == 1) || result == true;

  static TtsException _toTtsException(Object error, StackTrace stackTrace) {
    if (error is TtsException) return error;
    return TtsException('语音播放不可用，请稍后重试。', cause: error);
  }
}
