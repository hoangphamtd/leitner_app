import 'package:flutter_test/flutter_test.dart';
import 'package:leitner_app/models/flashcard.dart';
import 'package:leitner_app/models/study_log.dart';
import 'package:leitner_app/services/stats_service.dart';
import 'package:leitner_app/widgets/highlighted_sentence.dart';

Flashcard makeCard({
  required String id,
  int boxNumber = 1,
  bool isActive = true,
}) {
  final epoch = DateTime(2025, 1, 1);
  return Flashcard(
    id: id,
    word: 'w$id',
    phonetic: '/w/',
    meaning: 'nghĩa',
    exampleSentence: 'Câu ví dụ.',
    boxNumber: boxNumber,
    nextReviewDate: epoch,
    isActive: isActive,
    createdAt: epoch,
    updatedAt: epoch,
  );
}

StudyLog makeLog(DateTime at) => StudyLog(
  id: 'log-${at.toIso8601String()}',
  cardId: 'card',
  answeredAt: at,
  isCorrect: true,
  boxBefore: 1,
  boxAfter: 2,
);

void main() {
  const stats = StatsService();

  group('Số từ đã thuộc', () {
    test('Chỉ đếm thẻ đang ở Hộp 5', () {
      final cards = [
        makeCard(id: 'a', boxNumber: 5),
        makeCard(id: 'b', boxNumber: 5),
        makeCard(id: 'c', boxNumber: 4),
        makeCard(id: 'd', boxNumber: 1),
      ];
      expect(stats.countMastered(cards), 2);
    });

    test('Thẻ chưa kích hoạt không được tính, dù đang ở Hộp 5', () {
      final cards = [
        makeCard(id: 'a', boxNumber: 5),
        makeCard(id: 'b', boxNumber: 5, isActive: false),
      ];
      expect(stats.countMastered(cards), 1);
    });

    test('Bộ thẻ rỗng thì trả về 0', () {
      expect(stats.countMastered(const []), 0);
    });
  });

  group('Chuỗi ngày học liên tiếp', () {
    final today = DateTime(2025, 5, 10);

    test('Chưa học ngày nào thì chuỗi bằng 0', () {
      expect(stats.calculateStreak(const [], today), 0);
    });

    test('Học liền ba ngày tính tới hôm nay thì chuỗi bằng 3', () {
      final logs = [
        makeLog(DateTime(2025, 5, 8, 20)),
        makeLog(DateTime(2025, 5, 9, 7)),
        makeLog(DateTime(2025, 5, 10, 21)),
      ];
      expect(stats.calculateStreak(logs, today), 3);
    });

    test('Nhiều lượt trong cùng một ngày chỉ tính là một ngày', () {
      final logs = [
        makeLog(DateTime(2025, 5, 10, 8)),
        makeLog(DateTime(2025, 5, 10, 12)),
        makeLog(DateTime(2025, 5, 10, 22)),
      ];
      expect(stats.calculateStreak(logs, today), 1);
    });

    test('Hôm nay chưa học nhưng hôm qua có thì chuỗi vẫn giữ', () {
      // Người học thường mở app vào buổi tối. Nếu sáng ra đã thấy chuỗi về 0
      // thì con số này mất hết tác dụng động viên.
      final logs = [
        makeLog(DateTime(2025, 5, 8, 20)),
        makeLog(DateTime(2025, 5, 9, 20)),
      ];
      expect(stats.calculateStreak(logs, today), 2);
    });

    test('Bỏ trọn một ngày thì chuỗi đứt', () {
      final logs = [
        makeLog(DateTime(2025, 5, 6)),
        makeLog(DateTime(2025, 5, 7)),
        // Không học ngày 8 và 9.
        makeLog(DateTime(2025, 5, 10)),
      ];
      expect(stats.calculateStreak(logs, today), 1);
    });

    test('Chỉ có nhật ký cũ, đã đứt từ lâu thì chuỗi bằng 0', () {
      final logs = [makeLog(DateTime(2025, 4, 1))];
      expect(stats.calculateStreak(logs, today), 0);
    });
  });

  group('Hộp nào có thẻ đến hạn hôm nay', () {
    final today = DateTime(2025, 5, 10);

    Flashcard due(String id, int box, DateTime when) {
      final epoch = DateTime(2025, 1, 1);
      return Flashcard(
        id: id,
        word: 'w',
        phonetic: '/w/',
        meaning: 'nghĩa',
        exampleSentence: 'Câu.',
        boxNumber: box,
        nextReviewDate: when,
        isActive: true,
        createdAt: epoch,
        updatedAt: epoch,
      );
    }

    test('Gom đúng các hộp có thẻ tới hạn, kể cả thẻ quá hạn từ hôm trước', () {
      final cards = [
        due('a', 1, DateTime(2025, 5, 10)),
        due('b', 3, DateTime(2025, 5, 1)), // quá hạn
        due('c', 5, DateTime(2025, 6, 1)), // chưa tới hạn
      ];
      expect(stats.boxesDueOn(cards, today), {1, 3});
    });

    test('Thẻ đến hạn cuối ngày hôm nay vẫn được tính', () {
      final cards = [due('a', 2, DateTime(2025, 5, 10, 23, 59))];
      expect(stats.boxesDueOn(cards, today), {2});
    });
  });

  group('Bôi đậm từ vựng trong câu ví dụ', () {
    test('Tìm đúng từ ở dạng nguyên vẹn', () {
      final range = HighlightedSentence.findHighlightRange(
        'She packed an apple in her bag.',
        'apple',
      );
      expect(range, isNotNull);
      expect(
        'She packed an apple in her bag.'.substring(range!.start, range.end),
        'apple',
      );
    });

    test('Tô trọn cả phần đuôi khi từ bị chia', () {
      const sentence = 'A colleague recommended this little restaurant.';
      final range = HighlightedSentence.findHighlightRange(
        sentence,
        'recommend',
      );
      expect(range, isNotNull);
      expect(sentence.substring(range!.start, range.end), 'recommended');
    });

    test('Không phân biệt hoa thường', () {
      const sentence = 'Weather has been cold this week.';
      final range = HighlightedSentence.findHighlightRange(sentence, 'weather');
      expect(range, isNotNull);
      expect(sentence.substring(range!.start, range.end), 'Weather');
    });

    test('Không tìm thấy thì trả về null, không bôi bừa', () {
      final range = HighlightedSentence.findHighlightRange(
        'Hoàn toàn không liên quan.',
        'elephant',
      );
      expect(range, isNull);
    });

    test('Từ rỗng hoặc câu rỗng thì trả về null', () {
      expect(HighlightedSentence.findHighlightRange('Câu nào đó.', ''), isNull);
      expect(HighlightedSentence.findHighlightRange('', 'word'), isNull);
    });
  });
}
