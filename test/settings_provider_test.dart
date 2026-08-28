import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:leitner_app/models/app_settings.dart';
import 'package:leitner_app/providers/settings_provider.dart';
import 'package:leitner_app/services/pronunciation_service.dart';

import 'fakes/fake_pronunciation.dart';
import 'fakes/fake_repositories.dart';

void main() {
  late FakeSettingsRepository repository;
  late FakePronunciation pronunciation;
  late SettingsProvider provider;

  const voiceA = TtsVoice(name: 'en-US-female-1', locale: 'en-US');
  const voiceB = TtsVoice(name: 'en-GB-male-2', locale: 'en-GB');

  setUp(() {
    repository = FakeSettingsRepository();
    pronunciation = FakePronunciation()..voicesToReturn = [voiceA, voiceB];
    provider = SettingsProvider(
      repository: repository,
      pronunciation: pronunciation,
    );
  });

  group('Nạp cài đặt', () {
    test('Cấu hình bộ đọc theo đúng cài đặt đã lưu', () async {
      repository.current = const AppSettings(
        ttsVoiceName: 'en-US-female-1',
        ttsVoiceLocale: 'en-US',
        ttsRate: 0.6,
      );

      await provider.load();

      expect(provider.isLoading, isFalse);
      expect(pronunciation.initCount, 1);
      expect(pronunciation.lastRateSet, 0.6);
      expect(provider.selectedVoice, voiceA);
      expect(provider.voices, [voiceA, voiceB]);
    });

    test('Giọng đã lưu không còn trên máy thì lùi về giọng mặc định', () async {
      // Người dùng đổi trình duyệt hoặc gỡ gói giọng — cài đặt cũ trỏ vào một
      // giọng không còn tồn tại.
      repository.current = const AppSettings(
        ttsVoiceName: 'giong-da-bien-mat',
        ttsVoiceLocale: 'en-US',
      );

      await provider.load();

      expect(provider.selectedVoice, isNull);
      expect(pronunciation.voiceWasCleared, isTrue);
      expect(repository.current.ttsVoiceName, isNull);
    });

    test('Máy không có giọng nào thì vẫn nạp xong, không ném lỗi', () async {
      pronunciation.voicesToReturn = const [];
      await provider.load();

      expect(provider.voices, isEmpty);
      expect(provider.isLoading, isFalse);
    });
  });

  group('Đổi cài đặt', () {
    setUp(() async {
      await provider.load();
    });

    test('Số từ mới mỗi ngày được lưu xuống kho', () async {
      await provider.setNewCardsPerDay(35);
      expect(provider.settings.newCardsPerDay, 35);
      expect(repository.current.newCardsPerDay, 35);
    });

    test('Số từ mới bị kẹp trong khoảng hợp lệ', () async {
      await provider.setNewCardsPerDay(0);
      expect(provider.settings.newCardsPerDay, 1);

      await provider.setNewCardsPerDay(9999);
      expect(provider.settings.newCardsPerDay, 200);
    });

    test('Đổi giọng thì cấu hình cả bộ đọc lẫn kho', () async {
      await provider.setVoice(voiceB);

      expect(pronunciation.lastVoiceSet, voiceB);
      expect(repository.current.ttsVoiceName, 'en-GB-male-2');
      expect(repository.current.ttsVoiceLocale, 'en-GB');
    });

    test('Chọn giọng mặc định thì xoá hẳn lựa chọn đã lưu', () async {
      await provider.setVoice(voiceB);
      await provider.setVoice(null);

      expect(provider.selectedVoice, isNull);
      expect(repository.current.ttsVoiceName, isNull);
      expect(repository.current.ttsVoiceLocale, isNull);
    });

    test('Tốc độ đọc được kẹp trong khoảng hợp lệ', () async {
      await provider.setRate(5);
      expect(provider.settings.ttsRate, 1.0);

      await provider.setRate(0);
      expect(provider.settings.ttsRate, 0.1);
    });

    test('Đổi chế độ sáng tối, đổi luôn ThemeMode của Flutter', () async {
      expect(provider.themeMode, ThemeMode.system);

      await provider.setThemeMode(AppThemeMode.dark);
      expect(provider.themeMode, ThemeMode.dark);
      expect(repository.current.themeMode, AppThemeMode.dark);

      await provider.setThemeMode(AppThemeMode.light);
      expect(provider.themeMode, ThemeMode.light);
    });
  });

  group('Chuyển đổi JSON của cài đặt', () {
    test('Giữ nguyên mọi trường qua một vòng xuất rồi nhập', () {
      final original = AppSettings(
        newCardsPerDay: 42,
        lastActivationDate: DateTime(2025, 5, 10),
        activatedCountToday: 7,
        ttsVoiceName: 'en-US-female-1',
        ttsVoiceLocale: 'en-US',
        ttsRate: 0.62,
        themeMode: AppThemeMode.dark,
      );

      final restored = AppSettings.fromJson(original.toJson());

      expect(restored.newCardsPerDay, 42);
      expect(restored.lastActivationDate, DateTime(2025, 5, 10));
      expect(restored.activatedCountToday, 7);
      expect(restored.ttsVoiceName, 'en-US-female-1');
      expect(restored.ttsRate, 0.62);
      expect(restored.themeMode, AppThemeMode.dark);
    });

    test('Tên chế độ giao diện lạ thì lùi về mặc định, không ném lỗi', () {
      // File sao lưu có thể do người dùng sửa tay, hoặc đến từ bản cũ hơn.
      final restored = AppSettings.fromJson({
        'newCardsPerDay': 20,
        'themeMode': 'mot-che-do-khong-ton-tai',
      });
      expect(restored.themeMode, AppThemeMode.system);
    });

    test('JSON thiếu trường mới vẫn đọc được, dùng giá trị mặc định', () {
      final restored = AppSettings.fromJson({'newCardsPerDay': 15});
      expect(restored.newCardsPerDay, 15);
      expect(restored.ttsRate, 0.45);
      expect(restored.themeMode, AppThemeMode.system);
      expect(restored.ttsVoiceName, isNull);
    });
  });
}
