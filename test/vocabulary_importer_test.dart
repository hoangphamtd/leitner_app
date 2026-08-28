import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leitner_app/data/sample_vocabulary.dart';
import 'package:leitner_app/models/flashcard.dart';
import 'package:leitner_app/services/vocabulary_importer.dart';

void main() {
  late VocabularyImporter importer;

  setUp(() {
    importer = VocabularyImporter();
  });

  group('Nạp từ vựng từ JSON', () {
    test('Nạp được bộ dữ liệu mẫu 15 từ vào thư viện rỗng', () {
      final result = importer.importFromMaps(sampleVocabulary, const []);

      expect(result.importedCount, 15);
      expect(result.duplicateCount, 0);
      expect(result.errors, isEmpty);
    });

    test('Thẻ mới nạp nằm im trong thư viện, chưa được kích hoạt', () {
      final result = importer.importFromMaps(sampleVocabulary, const []);

      for (final card in result.newCards) {
        expect(
          card.isActive,
          isFalse,
          reason: 'Từ mới nạp phải chờ người học chủ động kích hoạt',
        );
        expect(card.boxNumber, 1);
        expect(card.id, isNotEmpty);
        expect(card.reviewCount, 0);
        expect(
          card.audioPath,
          isNull,
          reason: 'Giai đoạn này chưa có file mp3',
        );
      }
    });

    test('Mỗi thẻ được cấp một mã riêng, không trùng nhau', () {
      final result = importer.importFromMaps(sampleVocabulary, const []);
      final ids = result.newCards.map((card) => card.id).toSet();
      expect(ids.length, 15);
    });

    test('Từ trùng với kho cũ bị bỏ qua, không phân biệt hoa thường', () {
      final existing = [
        Flashcard(
          id: 'cu-1',
          word: 'Weather',
          phonetic: '/ˈweðər/',
          meaning: 'thời tiết',
          exampleSentence: 'Câu cũ.',
          boxNumber: 3,
          nextReviewDate: DateTime(2025, 5, 4),
          isActive: true,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        ),
      ];

      final result = importer.importFromMaps(sampleVocabulary, existing);

      expect(result.importedCount, 14);
      expect(result.duplicateCount, 1);
    });

    test('Trùng ngay bên trong file cũng bị loại', () {
      final entries = [
        ...sampleVocabulary.take(2),
        // Lặp lại từ đầu tiên, viết hoa và thêm khoảng trắng thừa.
        {...sampleVocabulary.first, 'word': '  APPOINTMENT  '},
      ];

      final result = importer.importFromMaps(entries, const []);

      expect(result.importedCount, 2);
      expect(result.duplicateCount, 1);
    });

    test('Mục thiếu trường bắt buộc bị ghi lỗi, các mục còn lại vẫn nạp', () {
      final entries = [
        sampleVocabulary.first,
        {'word': 'broken', 'phonetic': '/ˈbroʊkən/'}, // thiếu nghĩa và ví dụ
        sampleVocabulary[1],
      ];

      final result = importer.importFromMaps(entries, const []);

      expect(
        result.importedCount,
        2,
        reason: 'Một từ hỏng không được chặn cả bộ từ vựng',
      );
      expect(result.errors.length, 1);
      expect(result.errors.first, contains('Mục thứ 2'));
    });

    test('Chuỗi JSON không hợp lệ thì ném FormatException', () {
      expect(
        () => importer.importFromJsonString('{khong-phai-json', const []),
        throwsFormatException,
      );
    });

    test('JSON hợp lệ nhưng không phải mảng thì ném FormatException', () {
      expect(
        () => importer.importFromJsonString('{"word":"x"}', const []),
        throwsFormatException,
      );
    });

    test('Nạp được từ chuỗi JSON thô', () {
      final raw = jsonEncode(sampleVocabulary.take(3).toList());
      final result = importer.importFromJsonString(raw, const []);
      expect(result.importedCount, 3);
    });
  });

  group('Chất lượng bộ dữ liệu mẫu', () {
    test('Có đúng 15 từ', () {
      expect(sampleVocabulary.length, 15);
    });

    test('Không có từ nào lặp lại', () {
      final words = sampleVocabulary
          .map((entry) => (entry['word'] as String).toLowerCase())
          .toSet();
      expect(words.length, 15);
    });

    test('Phiên âm luôn nằm trong cặp dấu gạch chéo', () {
      for (final entry in sampleVocabulary) {
        final phonetic = entry['phonetic'] as String;
        expect(phonetic.startsWith('/'), isTrue, reason: 'Sai ở: $phonetic');
        expect(phonetic.endsWith('/'), isTrue, reason: 'Sai ở: $phonetic');
      }
    });

    test('Câu ví dụ đủ dài và có chứa chính từ vựng đó', () {
      for (final entry in sampleVocabulary) {
        final word = entry['word'] as String;
        final sentence = (entry['exampleSentence'] as String).toLowerCase();

        expect(
          sentence.length,
          greaterThan(60),
          reason: 'Câu ví dụ của "$word" quá ngắn',
        );
        // So theo gốc từ để bắt được cả dạng chia đuôi, ví dụ
        // "recommend" xuất hiện trong câu dưới dạng "recommended".
        final stem = word.length > 5
            ? word.substring(0, word.length - 1)
            : word;
        expect(
          sentence.contains(stem.toLowerCase()),
          isTrue,
          reason: 'Câu ví dụ của "$word" không chứa chính từ đó',
        );
      }
    });

    test('Nghĩa tiếng Việt không bỏ trống', () {
      for (final entry in sampleVocabulary) {
        expect((entry['meaning'] as String).trim(), isNotEmpty);
      }
    });
  });
}
