import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leitner_app/models/app_settings.dart';
import 'package:leitner_app/models/flashcard.dart';
import 'package:leitner_app/models/study_log.dart';
import 'package:leitner_app/services/backup_service.dart';

Flashcard makeCard({required String id, String word = 'word'}) => Flashcard(
  id: id,
  word: word,
  phonetic: '/w/',
  meaning: 'nghĩa tiếng Việt',
  exampleSentence: 'Một câu ví dụ đời thường.',
  boxNumber: 3,
  nextReviewDate: DateTime(2025, 5, 13),
  isActive: true,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 5, 8),
  reviewCount: 4,
  lapseCount: 1,
);

StudyLog makeLog(String id) => StudyLog(
  id: id,
  cardId: 'the-1',
  answeredAt: DateTime(2025, 5, 10, 20),
  isCorrect: true,
  boxBefore: 2,
  boxAfter: 3,
);

void main() {
  const service = BackupService();

  group('Xuất sao lưu', () {
    test('Tên file theo đúng dạng leitner-backup-YYYYMMDD.json', () {
      expect(
        service.suggestedFileName(DateTime(2025, 5, 9)),
        'leitner-backup-20250509.json',
      );
      expect(
        service.suggestedFileName(DateTime(2025, 12, 25)),
        'leitner-backup-20251225.json',
      );
    });

    test('File có số phiên bản định dạng và ngày xuất', () {
      final raw = service.export(
        const BackupData(cards: [], logs: [], settings: AppSettings()),
        now: DateTime(2025, 5, 10, 21, 30),
      );
      final map = jsonDecode(raw) as Map<String, dynamic>;

      expect(map['formatVersion'], BackupService.formatVersion);
      expect(map['exportedAt'], '2025-05-10T21:30:00.000');
      expect(map['appName'], 'leitner_app');
    });

    test('Gom đủ thẻ, nhật ký và cài đặt', () {
      final raw = service.export(
        BackupData(
          cards: [
            makeCard(id: 'a'),
            makeCard(id: 'b'),
          ],
          logs: [makeLog('log-1')],
          settings: const AppSettings(newCardsPerDay: 30),
        ),
      );
      final map = jsonDecode(raw) as Map<String, dynamic>;

      expect((map['cards'] as List).length, 2);
      expect((map['logs'] as List).length, 1);
      expect((map['settings'] as Map)['newCardsPerDay'], 30);
    });
  });

  group('Xuất rồi nhập lại', () {
    test('Dữ liệu giữ nguyên qua trọn một vòng', () {
      final original = BackupData(
        cards: [
          makeCard(id: 'a', word: 'apple'),
          makeCard(id: 'b'),
        ],
        logs: [makeLog('log-1'), makeLog('log-2')],
        settings: const AppSettings(
          newCardsPerDay: 30,
          ttsRate: 0.7,
          themeMode: AppThemeMode.dark,
        ),
      );

      final restored = service.import(service.export(original));

      expect(restored.cards.length, 2);
      expect(restored.cards.first.word, 'apple');
      expect(restored.cards.first.boxNumber, 3);
      expect(restored.cards.first.meaning, 'nghĩa tiếng Việt');
      expect(restored.cards.first.reviewCount, 4);
      expect(restored.cards.first.nextReviewDate, DateTime(2025, 5, 13));
      expect(restored.logs.length, 2);
      expect(restored.settings.newCardsPerDay, 30);
      expect(restored.settings.themeMode, AppThemeMode.dark);
    });

    test('Bản tóm tắt đọc đúng số liệu để người dùng xác nhận', () {
      final raw = service.export(
        BackupData(
          cards: [
            makeCard(id: 'a'),
            makeCard(id: 'b'),
            makeCard(id: 'c'),
          ],
          logs: [makeLog('log-1')],
          settings: const AppSettings(),
        ),
        now: DateTime(2025, 5, 10),
      );

      final preview = service.preview(raw);

      expect(preview.cardCount, 3);
      expect(preview.logCount, 1);
      expect(preview.exportedAt, DateTime(2025, 5, 10));
      expect(preview.formatVersion, 1);
    });
  });

  group('Kiểm tra file trước khi ghi đè', () {
    test('File của phiên bản mới hơn thì từ chối', () {
      // Bản cũ mà cố đọc file của bản mới sẽ hiểu sai cấu trúc rồi ghi đè bằng
      // dữ liệu hỏng — thà từ chối thẳng.
      final raw = jsonEncode({
        'formatVersion': BackupService.formatVersion + 1,
        'cards': [],
      });
      expect(() => service.import(raw), throwsA(isA<BackupException>()));
    });

    test('File không có số phiên bản thì từ chối', () {
      final raw = jsonEncode({'cards': []});
      expect(() => service.import(raw), throwsA(isA<BackupException>()));
    });

    test('JSON hỏng thì ném BackupException chứ không phải lỗi thô', () {
      expect(
        () => service.import('{khong-phai-json'),
        throwsA(isA<BackupException>()),
      );
    });

    test('Thiếu danh sách thẻ thì từ chối', () {
      final raw = jsonEncode({'formatVersion': 1});
      expect(() => service.import(raw), throwsA(isA<BackupException>()));
    });

    test('Một thẻ hỏng thì huỷ CẢ lượt nhập, không nhập nửa vời', () {
      // Nhập nửa vời để lại kho vừa thiếu thẻ vừa sai tiến độ, mà người dùng
      // lại tưởng đã khôi phục xong — tệ hơn hẳn việc báo lỗi rõ ràng.
      final raw = jsonEncode({
        'formatVersion': 1,
        'cards': [
          makeCard(id: 'a').toJson(),
          {'id': 'b', 'word': 'thieu-cac-truong-khac'},
        ],
      });
      expect(() => service.import(raw), throwsA(isA<BackupException>()));
    });

    test('Một dòng nhật ký hỏng thì chỉ bỏ dòng đó, thẻ vẫn nhập được', () {
      // Nhật ký chỉ phục vụ thống kê, không đáng để huỷ cả lượt khôi phục thẻ.
      final raw = jsonEncode({
        'formatVersion': 1,
        'cards': [makeCard(id: 'a').toJson()],
        'logs': [
          makeLog('log-1').toJson(),
          {'id': 'hong'},
        ],
      });

      final restored = service.import(raw);

      expect(restored.cards.length, 1);
      expect(restored.logs.length, 1);
    });

    test('File thiếu phần cài đặt thì dùng cài đặt mặc định', () {
      final raw = jsonEncode({
        'formatVersion': 1,
        'cards': [makeCard(id: 'a').toJson()],
      });
      final restored = service.import(raw);
      expect(restored.settings.newCardsPerDay, 20);
    });
  });

  group('Nhắc sao lưu sau 14 ngày', () {
    final now = DateTime(2025, 5, 20);

    test('Chưa từng sao lưu mà đã có thẻ thì nhắc', () {
      expect(
        service.shouldRemindBackup(lastBackupAt: null, cardCount: 15, now: now),
        isTrue,
      );
    });

    test('Kho rỗng thì không nhắc, dù chưa sao lưu bao giờ', () {
      // Nhắc sao lưu một kho trống thì vô nghĩa và chỉ gây phiền.
      expect(
        service.shouldRemindBackup(lastBackupAt: null, cardCount: 0, now: now),
        isFalse,
      );
    });

    test('Vừa sao lưu hôm qua thì chưa nhắc', () {
      expect(
        service.shouldRemindBackup(
          lastBackupAt: DateTime(2025, 5, 19),
          cardCount: 15,
          now: now,
        ),
        isFalse,
      );
    });

    test('Đúng 14 ngày thì bắt đầu nhắc', () {
      expect(
        service.shouldRemindBackup(
          lastBackupAt: DateTime(2025, 5, 6),
          cardCount: 15,
          now: now,
        ),
        isTrue,
      );
    });

    test('13 ngày thì chưa nhắc', () {
      expect(
        service.shouldRemindBackup(
          lastBackupAt: DateTime(2025, 5, 7),
          cardCount: 15,
          now: now,
        ),
        isFalse,
      );
    });
  });
}
