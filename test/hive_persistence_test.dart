import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:leitner_app/hive_registrar.g.dart';
import 'package:leitner_app/models/app_settings.dart';
import 'package:leitner_app/models/flashcard.dart';
import 'package:leitner_app/models/session_state.dart';
import 'package:leitner_app/models/study_log.dart';
import 'package:leitner_app/repositories/hive_card_repository.dart';
import 'package:leitner_app/repositories/hive_session_state_repository.dart';
import 'package:leitner_app/repositories/hive_settings_repository.dart';
import 'package:leitner_app/repositories/hive_study_log_repository.dart';

/// Ghi và đọc thật xuống Hive.
///
/// Các test khác dùng repository giả trong bộ nhớ nên chạy nhanh, nhưng chúng
/// KHÔNG bao giờ chạm tới Hive — vì vậy không phát hiện được lỗi thiếu adapter.
/// Đã vấp đúng lỗi đó một lần: thêm trường enum `themeMode` vào [AppSettings] mà
/// quên đánh dấu `@HiveType` cho enum, toàn bộ test vẫn xanh nhưng bản chạy thật
/// ném `HiveError: Cannot write, unknown type` ngay khi người dùng đổi cài đặt.
///
/// Nhóm test này tồn tại để bịt đúng khoảng trống đó: mỗi model phải ghi xuống
/// rồi đọc lại được nguyên vẹn.
void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('leitner_hive_test');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    // Mỗi bài test bắt đầu từ kho trống để không dính dữ liệu của bài trước.
    await Hive.deleteBoxFromDisk(HiveCardRepository.boxName);
    await Hive.deleteBoxFromDisk(HiveStudyLogRepository.boxName);
    await Hive.deleteBoxFromDisk(HiveSettingsRepository.boxName);
    await Hive.deleteBoxFromDisk(HiveSessionStateRepository.boxName);
  });

  group('Ghi và đọc thật xuống Hive', () {
    test('Flashcard giữ nguyên mọi trường sau một vòng ghi rồi đọc', () async {
      final repository = HiveCardRepository();
      await repository.init();

      final card = Flashcard(
        id: 'the-1',
        word: 'available',
        phonetic: '/əˈveɪləbl/',
        meaning: 'có sẵn, rảnh',
        exampleSentence: 'The doctor is not available this morning.',
        imagePath: null,
        audioPath: null,
        boxNumber: 3,
        nextReviewDate: DateTime(2025, 5, 13),
        isActive: true,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 5, 8),
        reviewCount: 4,
        lapseCount: 1,
      );
      await repository.save(card);

      final loaded = await repository.getById('the-1');
      expect(loaded, isNotNull);
      expect(loaded!.word, 'available');
      expect(loaded.phonetic, '/əˈveɪləbl/');
      expect(loaded.meaning, 'có sẵn, rảnh', reason: 'Tiếng Việt có dấu');
      expect(loaded.boxNumber, 3);
      expect(loaded.nextReviewDate, DateTime(2025, 5, 13));
      expect(loaded.isActive, isTrue);
      expect(loaded.reviewCount, 4);
      expect(loaded.lapseCount, 1);
      expect(loaded.imagePath, isNull);
    });

    test('Đếm theo hộp và lọc thẻ đến hạn chạy đúng trên kho thật', () async {
      final repository = HiveCardRepository();
      await repository.init();

      Flashcard make(String id, int box, DateTime due, {bool active = true}) =>
          Flashcard(
            id: id,
            word: 'w$id',
            phonetic: '/w/',
            meaning: 'nghĩa',
            exampleSentence: 'Câu.',
            boxNumber: box,
            nextReviewDate: due,
            isActive: active,
            createdAt: DateTime(2025),
            updatedAt: DateTime(2025),
          );

      await repository.saveAll([
        make('a', 1, DateTime(2025, 5, 10)),
        make('b', 1, DateTime(2025, 5, 1)),
        make('c', 4, DateTime(2025, 6, 1)),
        make('d', 2, DateTime(2025, 5, 10), active: false),
      ]);

      final counts = await repository.countByBox();
      expect(counts[1], 2);
      expect(counts[4], 1);
      expect(counts[2], 0, reason: 'Thẻ chưa kích hoạt không được đếm');
      expect(counts.keys.toList()..sort(), [1, 2, 3, 4, 5]);

      final due = await repository.getDueCards(DateTime(2025, 5, 10));
      expect(due.map((card) => card.id).toSet(), {'a', 'b'});

      final inactive = await repository.getInactiveCards();
      expect(inactive.single.id, 'd');
    });

    test('StudyLog ghi và đọc lại được', () async {
      final repository = HiveStudyLogRepository();
      await repository.init();

      await repository.append(
        StudyLog(
          id: 'log-1',
          cardId: 'the-1',
          answeredAt: DateTime(2025, 5, 10, 21, 30),
          isCorrect: false,
          boxBefore: 4,
          boxAfter: 1,
        ),
      );

      final all = await repository.getAll();
      expect(all.single.cardId, 'the-1');
      expect(all.single.isCorrect, isFalse);
      expect(all.single.boxBefore, 4);
      expect(all.single.boxAfter, 1);
    });

    test('AppSettings ghi được, KỂ CẢ trường enum themeMode', () async {
      // Đây chính là bài test bịt lỗi đã vấp phải: enum không có adapter thì
      // dòng save() dưới đây ném HiveError.
      final repository = HiveSettingsRepository();
      await repository.init();

      await repository.save(
        AppSettings(
          newCardsPerDay: 35,
          lastActivationDate: DateTime(2025, 5, 10),
          activatedCountToday: 12,
          ttsVoiceName: 'en-US-female-1',
          ttsVoiceLocale: 'en-US',
          ttsRate: 0.62,
          themeMode: AppThemeMode.dark,
        ),
      );

      final loaded = await repository.load();
      expect(loaded.newCardsPerDay, 35);
      expect(loaded.lastActivationDate, DateTime(2025, 5, 10));
      expect(loaded.activatedCountToday, 12);
      expect(loaded.ttsVoiceName, 'en-US-female-1');
      expect(loaded.ttsRate, 0.62);
      expect(loaded.themeMode, AppThemeMode.dark);
    });

    test('Cả ba chế độ giao diện đều ghi đọc được', () async {
      final repository = HiveSettingsRepository();
      await repository.init();

      for (final mode in AppThemeMode.values) {
        await repository.save(AppSettings(themeMode: mode));
        expect((await repository.load()).themeMode, mode);
      }
    });

    test('Lần chạy đầu chưa có cài đặt thì trả về giá trị mặc định', () async {
      final repository = HiveSettingsRepository();
      await repository.init();

      final loaded = await repository.load();
      expect(loaded.newCardsPerDay, 20);
      expect(loaded.themeMode, AppThemeMode.system);
      expect(loaded.ttsVoiceName, isNull);
    });

    test('SessionState ghi được, giữ đúng thứ tự hàng đợi', () async {
      final repository = HiveSessionStateRepository();
      await repository.init();

      await repository.save(
        SessionState(
          queueCardIds: const ['c', 'a', 'b'],
          failedCardIds: const ['a'],
          completedCardIds: const ['d'],
          initialCount: 4,
          correctAnswers: 1,
          wrongAnswers: 1,
          startedAt: DateTime(2025, 5, 10, 8, 15),
        ),
      );

      final loaded = await repository.load();
      expect(loaded, isNotNull);
      expect(loaded!.queueCardIds, [
        'c',
        'a',
        'b',
      ], reason: 'Thứ tự hàng đợi phải giữ nguyên tuyệt đối');
      expect(loaded.failedCardIds, ['a']);
      expect(loaded.startedAt, DateTime(2025, 5, 10, 8, 15));

      await repository.clear();
      expect(await repository.load(), isNull);
    });

    test('Dữ liệu sống sót qua việc đóng rồi mở lại kho', () async {
      // Mô phỏng người học đóng trình duyệt rồi mở lại.
      final first = HiveCardRepository();
      await first.init();
      await first.save(
        Flashcard(
          id: 'ben-vung',
          word: 'persist',
          phonetic: '/pərˈsɪst/',
          meaning: 'bền bỉ',
          exampleSentence: 'The data should persist across restarts.',
          boxNumber: 2,
          nextReviewDate: DateTime(2025, 5, 12),
          isActive: true,
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
        ),
      );
      await Hive.box<Flashcard>(HiveCardRepository.boxName).close();

      final second = HiveCardRepository();
      await second.init();
      final loaded = await second.getById('ben-vung');

      expect(loaded, isNotNull);
      expect(loaded!.meaning, 'bền bỉ');
      expect(loaded.boxNumber, 2);
    });
  });
}
