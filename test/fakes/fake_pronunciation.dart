import 'package:leitner_app/models/flashcard.dart';
import 'package:leitner_app/services/pronunciation_service.dart';

/// Bộ đọc giả: ghi lại các lệnh được gọi thay vì thật sự phát tiếng.
///
/// Kế thừa [PronunciationService] và chặn mọi phương thức chạm tới nền tảng, để
/// test không cần bộ đọc thật của hệ điều hành.
class FakePronunciation extends PronunciationService {
  List<TtsVoice> voicesToReturn = const [];
  TtsVoice? lastVoiceSet;
  bool voiceWasCleared = false;
  double lastRateSet = PronunciationService.defaultRate;
  int initCount = 0;
  final List<String> spokenWords = [];
  final List<String> spokenSentences = [];

  @override
  Future<void> init({
    String? voiceName,
    String? voiceLocale,
    double rate = PronunciationService.defaultRate,
  }) async {
    initCount++;
    lastRateSet = rate;
  }

  @override
  Future<List<TtsVoice>> availableVoices() async => voicesToReturn;

  @override
  Future<bool> setVoice(TtsVoice? voice) async {
    lastVoiceSet = voice;
    if (voice == null) voiceWasCleared = true;
    return true;
  }

  @override
  Future<void> setRate(double rate) async {
    lastRateSet = rate.clamp(0.1, 1.0);
  }

  @override
  double get rate => lastRateSet;

  @override
  Future<void> speakWord(Flashcard card) async => spokenWords.add(card.word);

  @override
  Future<void> speakSentence(Flashcard card) async =>
      spokenSentences.add(card.exampleSentence);

  @override
  Future<void> stop() async {}
}
