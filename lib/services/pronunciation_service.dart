import 'package:flutter_tts/flutter_tts.dart';

import '../models/flashcard.dart';
import '../utils/logger.dart';

/// Một giọng đọc máy có sẵn trên thiết bị.
class TtsVoice {
  /// Mã giọng, ví dụ `en-US-x-sfg#male_1-local`.
  final String name;

  /// Ngôn ngữ của giọng, ví dụ `en-US`.
  final String locale;

  const TtsVoice({required this.name, required this.locale});

  /// Tên rút gọn để hiển thị cho người dùng.
  ///
  /// Mã giọng thô thường rất dài và khó đọc, nên cắt bớt phần định danh kỹ
  /// thuật phía sau dấu thăng.
  String get displayName {
    final cut = name.indexOf('#');
    return cut > 0 ? name.substring(0, cut) : name;
  }

  @override
  bool operator ==(Object other) =>
      other is TtsVoice && other.name == name && other.locale == locale;

  @override
  int get hashCode => Object.hash(name, locale);
}

/// Bọc toàn bộ việc phát âm.
///
/// SOP Phần 5 yêu cầu tách riêng lớp này để sau đổi nguồn tiếng — chuyển từ
/// giọng máy sang file mp3 thu sẵn — mà không phải sửa một dòng giao diện nào.
/// Vì vậy giao diện chỉ được gọi [speakWord] và [speakSentence], tuyệt đối không
/// gọi thẳng `FlutterTts`.
class PronunciationService {
  /// Ngôn ngữ đọc. Ứng dụng dạy tiếng Anh Mỹ nên cố định `en-US`.
  static const String language = 'en-US';

  /// Tốc độ đọc mặc định, chậm hơn mức thường để người học nghe rõ từng âm.
  static const double defaultRate = 0.45;

  final Logger _log = const Logger('PronunciationService');

  /// Bộ đọc của nền tảng, khởi tạo TRỄ.
  ///
  /// Cố ý không tạo trong hàm dựng: `FlutterTts()` đăng ký ngay một kênh giao
  /// tiếp với nền tảng, nên tạo sớm sẽ khiến lớp này không dựng nổi ở nơi chưa
  /// có binding của Flutter — kể cả khi mọi phương thức đều đã được lớp con
  /// thay thế. Khởi tạo trễ giúp lớp chỉ chạm tới nền tảng đúng lúc thật sự cần.
  FlutterTts? _ttsOrNull;

  FlutterTts get _tts => _ttsOrNull ??= FlutterTts();

  PronunciationService({FlutterTts? tts}) : _ttsOrNull = tts;

  bool _initialized = false;
  double _rate = defaultRate;

  /// Nạp cấu hình ban đầu.
  ///
  /// Mọi lỗi ở đây đều được nuốt lại có chủ ý và ghi nhật ký: máy không có bộ
  /// đọc, hoặc trình duyệt chặn — đó là chuyện thường gặp và không được phép
  /// chặn người học dùng app. Hệ quả là nút loa im lặng, chứ app không sập.
  Future<void> init({
    String? voiceName,
    String? voiceLocale,
    double rate = defaultRate,
  }) async {
    try {
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(rate);
      _rate = rate;
      if (voiceName != null && voiceLocale != null) {
        await setVoice(TtsVoice(name: voiceName, locale: voiceLocale));
      }
      _initialized = true;
    } catch (error, stackTrace) {
      _log.warning('Không khởi tạo được bộ đọc: $error');
      _log.debug(stackTrace.toString());
      _initialized = false;
    }
  }

  /// Số lần thử lại khi lấy danh sách giọng, và quãng nghỉ giữa hai lần.
  ///
  /// Trên trình duyệt, `speechSynthesis.getVoices()` trả về danh sách RỖNG ở lần
  /// gọi đầu tiên: trình duyệt nạp giọng bất đồng bộ và chỉ báo xong qua sự kiện
  /// `voiceschanged`. Gọi một lần rồi kết luận "máy không có giọng" là sai — đã
  /// vấp đúng lỗi này khi chạy thử: Chrome có sẵn 6 giọng tiếng Anh mà màn hình
  /// Cài đặt vẫn báo không có giọng nào.
  static const int _voiceRetries = 6;
  static const Duration _voiceRetryDelay = Duration(milliseconds: 250);

  /// Danh sách giọng có sẵn, đã lọc còn tiếng Anh.
  ///
  /// Thử lại vài lần trước khi chịu thua, vì lý do nói ở [_voiceRetries]. Trả về
  /// danh sách rỗng khi máy thật sự không có bộ đọc — phía giao diện phải chịu
  /// được trường hợp đó và hiển thị lời nhắc thay vì một ô chọn trống trơn.
  Future<List<TtsVoice>> availableVoices() async {
    for (var attempt = 0; attempt <= _voiceRetries; attempt++) {
      final voices = await _readVoicesOnce();
      if (voices.isNotEmpty) return voices;
      if (attempt < _voiceRetries) await Future.delayed(_voiceRetryDelay);
    }
    _log.warning('Máy không có giọng đọc tiếng Anh nào');
    return const [];
  }

  /// Đọc danh sách giọng đúng một lần, không thử lại.
  Future<List<TtsVoice>> _readVoicesOnce() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return const [];

      final voices = <TtsVoice>[];
      for (final entry in raw) {
        if (entry is! Map) continue;
        final name = entry['name']?.toString();
        final locale = entry['locale']?.toString();
        if (name == null || locale == null) continue;
        // Chỉ giữ giọng tiếng Anh; giọng tiếng khác đọc từ vựng Anh sẽ sai âm.
        if (!locale.toLowerCase().startsWith('en')) continue;
        voices.add(TtsVoice(name: name, locale: locale));
      }

      // Bỏ trùng rồi sắp xếp cho danh sách ổn định giữa các lần mở.
      final unique = voices.toSet().toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      return unique;
    } catch (error) {
      _log.warning('Không đọc được danh sách giọng: $error');
      return const [];
    }
  }

  /// Chọn giọng. Giọng không còn tồn tại thì lùi về mặc định của hệ thống.
  Future<bool> setVoice(TtsVoice? voice) async {
    try {
      if (voice == null) {
        await _tts.setLanguage(language);
        return true;
      }
      await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
      return true;
    } catch (error) {
      _log.warning('Không đặt được giọng ${voice?.name}: $error');
      return false;
    }
  }

  /// Đặt tốc độ đọc, kẹp trong khoảng hợp lệ.
  Future<void> setRate(double rate) async {
    final clamped = rate.clamp(0.1, 1.0);
    _rate = clamped;
    try {
      await _tts.setSpeechRate(clamped);
    } catch (error) {
      _log.warning('Không đặt được tốc độ đọc: $error');
    }
  }

  double get rate => _rate;

  /// Đọc từ vựng của một thẻ.
  ///
  /// Theo SOP Phần 5: có file mp3 riêng thì phát file đó, không có thì nhờ giọng
  /// máy. Giai đoạn này `audioPath` luôn null nên luôn rơi vào nhánh giọng máy —
  /// nhánh phát file được chừa sẵn để giai đoạn thu âm sau chỉ việc điền vào.
  Future<void> speakWord(Flashcard card) async {
    final audioPath = card.audioPath;
    if (audioPath != null && audioPath.isNotEmpty) {
      await _playAudioFile(audioPath);
      return;
    }
    await _speak(card.word);
  }

  /// Đọc câu ví dụ. Câu ví dụ LUÔN dùng giọng máy, kể cả khi thẻ có file mp3 —
  /// file thu sẵn chỉ thu mỗi từ chứ không thu cả câu.
  Future<void> speakSentence(Flashcard card) => _speak(card.exampleSentence);

  /// Dừng ngay việc đọc. Gọi khi người học chuyển sang thẻ khác.
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (error) {
      _log.warning('Không dừng được bộ đọc: $error');
    }
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    if (!_initialized) await init(rate: _rate);
    try {
      // Dừng câu đang đọc dở trước khi đọc câu mới, tránh hai giọng chồng nhau
      // khi người học bấm loa liên tục.
      await _tts.stop();
      await _tts.speak(text);
    } catch (error, stackTrace) {
      _log.error('Không đọc được "$text"', error, stackTrace);
    }
  }

  /// Chừa sẵn cho giai đoạn có file mp3 thu trước.
  ///
  /// Hiện chưa có nguồn audio nào nên chỉ ghi nhật ký. Cố ý KHÔNG lặng lẽ lùi
  /// về giọng máy: nếu thẻ khai báo có file mà file không phát được thì đó là
  /// lỗi dữ liệu, phải thấy được chứ không nên giấu đi.
  Future<void> _playAudioFile(String path) async {
    _log.warning('Chưa hỗ trợ phát file audio: $path');
  }
}
