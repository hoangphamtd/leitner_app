import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../models/app_settings.dart';
import '../models/flashcard.dart';
import '../repositories/settings_repository.dart';
import '../services/pronunciation_service.dart';
import '../utils/logger.dart';

/// Quản lý cài đặt ứng dụng và nối chúng vào bộ đọc.
///
/// Provider này là nơi duy nhất biết rằng thay đổi cài đặt giọng phải kéo theo
/// việc cấu hình lại [PronunciationService]. Giao diện chỉ gọi các phương thức
/// ở đây và không cần biết tới mối liên hệ đó.
class SettingsProvider extends ChangeNotifier {
  final SettingsRepository repository;
  final PronunciationService pronunciation;
  final Logger _log = const Logger('SettingsProvider');

  SettingsProvider({required this.repository, required this.pronunciation});

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  List<TtsVoice> _voices = const [];

  /// Danh sách giọng máy có sẵn. Rỗng nghĩa là máy không có bộ đọc nào dùng được.
  List<TtsVoice> get voices => _voices;

  bool _loading = true;
  bool get isLoading => _loading;

  /// Chế độ giao diện, đã đổi sang kiểu của Flutter.
  ThemeMode get themeMode => switch (_settings.themeMode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  /// Giọng đang chọn, hoặc null nếu đang dùng giọng mặc định của hệ thống.
  TtsVoice? get selectedVoice {
    final name = _settings.ttsVoiceName;
    final locale = _settings.ttsVoiceLocale;
    if (name == null || locale == null) return null;
    return TtsVoice(name: name, locale: locale);
  }

  /// Đọc cài đặt từ kho rồi cấu hình bộ đọc theo đúng cài đặt đó.
  Future<void> load() async {
    try {
      _settings = await repository.load();
      await pronunciation.init(
        voiceName: _settings.ttsVoiceName,
        voiceLocale: _settings.ttsVoiceLocale,
        rate: _settings.ttsRate,
      );
      _voices = await pronunciation.availableVoices();

      // Giọng đã lưu có thể không còn trên máy này — người dùng đổi trình duyệt,
      // hoặc gỡ gói giọng. Khi đó xoá lựa chọn để lùi về giọng mặc định, thay vì
      // để ô chọn trỏ vào một giọng không tồn tại.
      final saved = selectedVoice;
      if (saved != null && !_voices.contains(saved)) {
        _log.warning('Giọng đã lưu không còn tồn tại, lùi về giọng mặc định');
        await _persist(_settings.copyWith(clearTtsVoice: true));
        await pronunciation.setVoice(null);
      }
    } catch (error, stackTrace) {
      _log.error('Không đọc được cài đặt', error, stackTrace);
    }
    _loading = false;
    notifyListeners();
  }

  /// Đổi số từ mới mỗi ngày (mục 3.6).
  Future<void> setNewCardsPerDay(int value) async {
    // Chặn số vô lý ngay tại đây thay vì tin vào giao diện, vì cài đặt còn có
    // thể đến từ file sao lưu do người dùng sửa tay.
    final clamped = value.clamp(1, 200);
    await _persist(_settings.copyWith(newCardsPerDay: clamped));
  }

  /// Đổi giọng đọc. Truyền null để quay về giọng mặc định của hệ thống.
  Future<void> setVoice(TtsVoice? voice) async {
    await pronunciation.setVoice(voice);
    await _persist(
      voice == null
          ? _settings.copyWith(clearTtsVoice: true)
          : _settings.copyWith(
              ttsVoiceName: voice.name,
              ttsVoiceLocale: voice.locale,
            ),
    );
  }

  /// Đổi tốc độ đọc.
  Future<void> setRate(double rate) async {
    await pronunciation.setRate(rate);
    await _persist(_settings.copyWith(ttsRate: pronunciation.rate));
  }

  /// Đổi chế độ sáng/tối.
  Future<void> setThemeMode(AppThemeMode mode) async {
    await _persist(_settings.copyWith(themeMode: mode));
  }

  /// Ghi nhận người dùng đã bỏ qua lời mời cài app vào màn hình chính.
  Future<void> markInstallPromptDismissed({DateTime? now}) async {
    await _persist(
      _settings.copyWith(installPromptDismissedAt: now ?? DateTime.now()),
    );
  }

  /// Đọc thử một từ để người dùng nghe trước khi chốt giọng.
  Future<void> preview(Flashcard sample) => pronunciation.speakWord(sample);

  Future<void> _persist(AppSettings updated) async {
    _settings = updated;
    notifyListeners();
    try {
      await repository.save(updated);
    } catch (error, stackTrace) {
      _log.error('Không lưu được cài đặt', error, stackTrace);
    }
  }

  /// Nạp lại cài đặt từ kho.
  ///
  /// Cần khi tầng khác vừa ghi đè cài đặt — ví dụ bộ đếm từ mới trong ngày do
  /// [DeckProvider] cập nhật sau mỗi lượt kích hoạt thẻ.
  Future<void> reload() async {
    try {
      _settings = await repository.load();
      notifyListeners();
    } catch (error, stackTrace) {
      _log.error('Không nạp lại được cài đặt', error, stackTrace);
    }
  }
}
