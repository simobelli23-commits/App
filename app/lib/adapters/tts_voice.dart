import 'package:flutter_tts/flutter_tts.dart';
import 'package:scooter_core/scooter_core.dart';

/// Voce italiana tramite il motore TTS di sistema (nessun servizio esterno).
class TtsVoice implements VoiceOutput {
  final FlutterTts _tts = FlutterTts();
  bool? _italianAvailable;

  /// `false` se il dispositivo non ha una voce italiana installata.
  bool? get italianAvailable => _italianAvailable;

  Future<bool> init() async {
    try {
      final ok = await _tts.isLanguageAvailable('it-IT');
      _italianAvailable = ok == true;
      if (_italianAvailable!) {
        await _tts.setLanguage('it-IT');
        await _tts.setSpeechRate(0.5);
      }
    } catch (_) {
      _italianAvailable = false;
    }
    return _italianAvailable!;
  }

  @override
  Future<void> speak(String text) async {
    if (_italianAvailable == null) await init();
    // Meglio il silenzio che una pronuncia errata in un'altra lingua.
    if (_italianAvailable != true) return;
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
