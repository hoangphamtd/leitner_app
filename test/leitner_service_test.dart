import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:leitner_app/models/app_settings.dart';
import 'package:leitner_app/models/flashcard.dart';
import 'package:leitner_app/services/leitner_service.dart';
import 'package:leitner_app/services/study_session.dart';

/// Mã thẻ có tổng mã ký tự CHẴN, tức thuộc nhóm ôn Thứ Bảy ở Hộp 4.
/// Chuỗi 'aa' cho tổng 97 + 97 = 194.
const String evenCardId = 'aa';

/// Mã thẻ có tổng mã ký tự LẺ, tức thuộc nhóm ôn Chủ Nhật ở Hộp 4.
/// Chuỗi 'a' cho tổng 97.
const String oddCardId = 'a';

/// Dựng nhanh một thẻ để kiểm thử. Chỉ nhận những tham số mà bài test quan tâm,
/// phần còn lại điền giá trị mặc định vô hại.
Flashcard makeCard({
  required String id,
  String word = 'test',
  int boxNumber = 1,
  DateTime? nextReviewDate,
  bool isActive = true,
  int reviewCount = 0,
  int lapseCount = 0,
}) {
  final epoch = DateTime(2025, 1, 1);
  return Flashcard(
    id: id,
    word: word,
    phonetic: '/test/',
    meaning: 'thử nghiệm',
    exampleSentence: 'This is a test sentence.',
    boxNumber: boxNumber,
    nextReviewDate: nextReviewDate ?? epoch,
    isActive: isActive,
    createdAt: epoch,
    updatedAt: epoch,
    reviewCount: reviewCount,
    lapseCount: lapseCount,
  );
}

/// Bộ sinh mã nhật ký tất định, để kết quả test không phụ thuộc UUID ngẫu nhiên.
String Function() sequentialLogIds() {
  var counter = 0;
  return () => 'log-${++counter}';
}

void main() {
  late LeitnerService service;

  setUp(() {
    // Khoá hạt giống ngẫu nhiên để phần xáo trộn hàng đợi cho kết quả lặp lại
    // được giữa các lần chạy.
    service = LeitnerService(random: Random(20260827));
  });

  group('3.3 — Ba ví dụ kiểm chứng trong SOP', () {
    test('Hộp 3: lên hộp Thứ Sáu 01/05 thì hạn ôn là Thứ Ba 12/05', () {
      final friday = DateTime(2026, 5, 1);
      // Chốt lại giả định về thứ, để nếu chọn nhầm năm thì test báo ngay tại đây
      // chứ không âm thầm kiểm chứng sai đề bài.
      expect(
        friday.weekday,
        DateTime.friday,
        reason: '01/05/2026 phải là Thứ Sáu',
      );

      final result = service.calculateNextReviewDate(3, 'bat-ky', friday);

      expect(result, DateTime(2026, 5, 12));
      expect(result.weekday, DateTime.tuesday);
      // Tối thiểu 5 ngày đưa mốc sớm nhất tới 06/05, là Thứ Tư.
      expect(DateTime(2026, 5, 6).weekday, DateTime.wednesday);
    });

    test('Hộp 5: lên hộp ngày 10/06 thì hạn ôn là ngày 15/07', () {
      final result = service.calculateNextReviewDate(
        5,
        'bat-ky',
        DateTime(2025, 6, 10),
      );

      expect(result, DateTime(2025, 7, 15));
      // Tối thiểu 20 ngày đưa mốc sớm nhất tới 30/06, đã qua ngày 15 của tháng 6
      // nên phải nhảy sang ngày 15 tháng sau.
      expect(result.day, 15);
    });

    test(
      'Hộp 4 nhóm chẵn: lên hộp Chủ Nhật 04/05 thì hạn ôn là Thứ Bảy 17/05',
      () {
        final sunday = DateTime(2025, 5, 4);
        expect(
          sunday.weekday,
          DateTime.sunday,
          reason: '04/05/2025 phải là Chủ Nhật',
        );
        expect(
          LeitnerService.hashCardId(evenCardId).isEven,
          isTrue,
          reason: 'Thẻ mẫu phải thuộc nhóm chẵn',
        );

        final result = service.calculateNextReviewDate(4, evenCardId, sunday);

        expect(result, DateTime(2025, 5, 17));
        expect(result.weekday, DateTime.saturday);
        // Tối thiểu 12 ngày đưa mốc sớm nhất tới 16/05, là Thứ Sáu.
        expect(DateTime(2025, 5, 16).weekday, DateTime.friday);
      },
    );
  });

  group('3.2 — Quy tắc chia đôi Hộp 4', () {
    test('Thẻ nhóm chẵn ôn Thứ Bảy, thẻ nhóm lẻ ôn Chủ Nhật', () {
      expect(LeitnerService.weekendDayForCard(evenCardId), DateTime.saturday);
      expect(LeitnerService.weekendDayForCard(oddCardId), DateTime.sunday);
    });

    test('Hàm băm ổn định: cùng một mã thẻ luôn cho cùng một nhóm', () {
      const id = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';
      final firstCall = LeitnerService.weekendDayForCard(id);
      for (var i = 0; i < 50; i++) {
        expect(LeitnerService.weekendDayForCard(id), firstCall);
      }
    });

    test('Ngày ôn của hai nhóm luôn rơi đúng vào thứ của nhóm mình', () {
      // Quét đủ 7 mốc xuất phát khác nhau trong tuần, để chắc chắn luật đúng
      // với mọi ngày người học có thể lên Hộp 4, chứ không chỉ đúng ở ví dụ.
      for (var offset = 0; offset < 7; offset++) {
        final start = DateTime(2025, 5, 4 + offset);

        final evenResult = service.calculateNextReviewDate(
          4,
          evenCardId,
          start,
        );
        expect(evenResult.weekday, DateTime.saturday);
        expect(evenResult.difference(start).inDays, greaterThanOrEqualTo(12));

        final oddResult = service.calculateNextReviewDate(4, oddCardId, start);
        expect(oddResult.weekday, DateTime.sunday);
        expect(oddResult.difference(start).inDays, greaterThanOrEqualTo(12));
      }
    });

    test('Thẻ chỉ đi qua Hộp 4 đúng một lần, nên không có nhịp lặp lại', () {
      // Điểm này rất dễ hiểu nhầm. Hộp 4 KHÔNG phải một trạm ôn đi ôn lại: trả
      // lời đúng thì thẻ lên thẳng Hộp 5, trả lời sai thì rơi về Hộp 1. Không
      // có nhánh nào đưa thẻ ở Hộp 4 quay lại chính Hộp 4.
      final card = makeCard(id: evenCardId, boxNumber: 4);

      final correct = service.applyAnswer(
        card: card,
        isCorrect: true,
        logId: 'log-1',
        now: DateTime(2025, 5, 6),
      );
      expect(correct.updatedCard.boxNumber, 5);

      final wrong = service.applyAnswer(
        card: card,
        isCorrect: false,
        logId: 'log-2',
        now: DateTime(2025, 5, 6),
      );
      expect(wrong.updatedCard.boxNumber, 1);
    });

    test('Vào Hộp 4 từ Thứ Ba: nhóm chẵn 18 ngày, nhóm lẻ 12 ngày', () {
      // Thẻ chỉ lên Hộp 4 khi trả lời đúng ở Hộp 3, mà Hộp 3 chỉ đến hạn vào
      // Thứ Ba. Vậy nếu người học ôn đúng hạn thì ngày lên Hộp 4 luôn là Thứ Ba.
      // Thứ Ba cộng 12 ngày rơi đúng vào Chủ Nhật: nhóm lẻ dừng ngay tại đó,
      // còn nhóm chẵn phải đi tiếp 6 ngày nữa mới tới Thứ Bảy.
      final tuesday = DateTime(2025, 5, 6);
      expect(tuesday.weekday, DateTime.tuesday);
      expect(tuesday.add(const Duration(days: 12)).weekday, DateTime.sunday);

      expect(
        service
            .calculateNextReviewDate(4, evenCardId, tuesday)
            .difference(tuesday)
            .inDays,
        18,
      );
      expect(
        service
            .calculateNextReviewDate(4, oddCardId, tuesday)
            .difference(tuesday)
            .inDays,
        12,
      );
    });
  });

  group('3.1 — Lịch của từng hộp', () {
    test('Hộp 1 luôn đến hạn vào đúng ngày hôm sau', () {
      for (var offset = 0; offset < 7; offset++) {
        final start = DateTime(2025, 5, 4 + offset);
        expect(
          service.calculateNextReviewDate(1, 'x', start),
          DateTime(2025, 5, 5 + offset),
        );
      }
    });

    test(
      'Hộp 2 chỉ rơi vào Thứ Hai, Thứ Tư hoặc Thứ Sáu, cách ít nhất 2 ngày',
      () {
        for (var offset = 0; offset < 7; offset++) {
          final start = DateTime(2025, 5, 4 + offset);
          final result = service.calculateNextReviewDate(2, 'x', start);
          expect([
            DateTime.monday,
            DateTime.wednesday,
            DateTime.friday,
          ], contains(result.weekday));
          expect(result.difference(start).inDays, greaterThanOrEqualTo(2));
        }
      },
    );

    test('Hộp 3 chỉ rơi vào Thứ Ba, cách ít nhất 5 ngày', () {
      for (var offset = 0; offset < 7; offset++) {
        final start = DateTime(2025, 5, 4 + offset);
        final result = service.calculateNextReviewDate(3, 'x', start);
        expect(result.weekday, DateTime.tuesday);
        expect(result.difference(start).inDays, greaterThanOrEqualTo(5));
      }
    });

    test('Hộp 5 chỉ rơi vào ngày 15, cách ít nhất 20 ngày', () {
      for (var day = 1; day <= 28; day++) {
        final start = DateTime(2025, 3, day);
        final result = service.calculateNextReviewDate(5, 'x', start);
        expect(result.day, 15);
        expect(result.difference(start).inDays, greaterThanOrEqualTo(20));
      }
    });

    test('Giờ trong ngày không làm lệch kết quả', () {
      final morning = DateTime(2026, 5, 1, 6, 30);
      final lateNight = DateTime(2026, 5, 1, 23, 59, 59);
      expect(
        service.calculateNextReviewDate(3, 'x', morning),
        service.calculateNextReviewDate(3, 'x', lateNight),
      );
    });

    test('Kết quả luôn được đặt về đúng 00:00', () {
      final result = service.calculateNextReviewDate(
        2,
        'x',
        DateTime(2025, 5, 4, 17, 45, 12),
      );
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
      expect(result.millisecond, 0);
    });

    test('Hộp không hợp lệ thì ném lỗi chứ không trả về ngày bừa', () {
      expect(
        () => service.calculateNextReviewDate(0, 'x', DateTime(2025, 5, 4)),
        throwsArgumentError,
      );
      expect(
        () => service.calculateNextReviewDate(6, 'x', DateTime(2025, 5, 4)),
        throwsArgumentError,
      );
    });
  });

  group('3.4 — Xử lý khi người học trả lời', () {
    final now = DateTime(2025, 5, 4, 20, 15);

    test('Trả lời đúng thì lên một hộp và rời hàng đợi', () {
      final card = makeCard(id: 'x', boxNumber: 2, reviewCount: 3);

      final outcome = service.applyAnswer(
        card: card,
        isCorrect: true,
        logId: 'log-1',
        now: now,
      );

      expect(outcome.updatedCard.boxNumber, 3);
      expect(outcome.updatedCard.reviewCount, 4);
      expect(outcome.updatedCard.lapseCount, 0);
      expect(outcome.shouldRequeue, isFalse);
      expect(outcome.updatedCard.updatedAt, now);
      expect(outcome.log.isCorrect, isTrue);
      expect(outcome.log.boxBefore, 2);
      expect(outcome.log.boxAfter, 3);
    });

    test('Trả lời đúng ở Hộp 5 thì giữ nguyên Hộp 5, không tràn lên 6', () {
      final card = makeCard(id: 'x', boxNumber: 5);

      final outcome = service.applyAnswer(
        card: card,
        isCorrect: true,
        logId: 'log-1',
        now: now,
      );

      expect(outcome.updatedCard.boxNumber, 5);
      expect(outcome.updatedCard.nextReviewDate.day, 15);
    });

    test('Trả lời sai thì về Hộp 1, hẹn ngày mai, và ở lại hàng đợi', () {
      final card = makeCard(
        id: 'x',
        boxNumber: 4,
        reviewCount: 7,
        lapseCount: 1,
      );

      final outcome = service.applyAnswer(
        card: card,
        isCorrect: false,
        logId: 'log-1',
        now: now,
      );

      expect(outcome.updatedCard.boxNumber, 1);
      expect(outcome.updatedCard.nextReviewDate, DateTime(2025, 5, 5));
      expect(outcome.updatedCard.reviewCount, 8);
      expect(outcome.updatedCard.lapseCount, 2);
      expect(outcome.shouldRequeue, isTrue);
      expect(outcome.log.boxBefore, 4);
      expect(outcome.log.boxAfter, 1);
    });

    test('Lượt đúng sau khi đã sai trong buổi KHÔNG được tính là lên hộp', () {
      // Đây là luật dễ làm sai nhất của mục 3.4: thẻ đã sai thì lượt sửa được
      // trong cùng buổi chỉ cho phép rời hàng đợi, tuyệt đối không thăng hộp.
      final card = makeCard(
        id: 'x',
        boxNumber: 1,
        nextReviewDate: DateTime(2025, 5, 5),
        reviewCount: 8,
        lapseCount: 2,
      );

      final outcome = service.applyAnswer(
        card: card,
        isCorrect: true,
        alreadyFailedThisSession: true,
        logId: 'log-2',
        now: now,
      );

      expect(outcome.updatedCard.boxNumber, 1, reason: 'Phải giữ nguyên Hộp 1');
      expect(
        outcome.updatedCard.nextReviewDate,
        DateTime(2025, 5, 5),
        reason: 'Phải giữ nguyên lịch ngày mai đã đặt lúc trả lời sai',
      );
      expect(
        outcome.updatedCard.lapseCount,
        2,
        reason: 'Lượt đúng không làm tăng số lần sai',
      );
      expect(
        outcome.updatedCard.reviewCount,
        9,
        reason: 'Nhưng vẫn tính là một lượt ôn',
      );
      expect(outcome.shouldRequeue, isFalse);
      expect(outcome.log.boxBefore, 1);
      expect(outcome.log.boxAfter, 1);
    });
  });

  group('3.4 — Hàng đợi buổi học đẩy thẻ sai về cuối', () {
    test('Thẻ sai quay lại cuối hàng và chỉ rời đi khi trả lời đúng', () {
      final session = StudySession(
        queue: [
          makeCard(id: 'aa', word: 'one'),
          makeCard(id: 'bb', word: 'two'),
          makeCard(id: 'cc', word: 'three'),
        ],
        service: service,
        logIdFactory: sequentialLogIds(),
      );

      // Thẻ đầu trả lời SAI, phải xuống cuối chứ không biến mất.
      expect(session.currentCard!.word, 'one');
      final firstOutcome = session.answer(false);
      expect(firstOutcome.shouldRequeue, isTrue);
      expect(session.remainingCount, 3);
      expect(session.currentCard!.word, 'two');

      // Hai thẻ giữa trả lời ĐÚNG, rời hàng đợi ngay.
      session.answer(true);
      expect(session.currentCard!.word, 'three');
      session.answer(true);

      // Giờ mới quay về thẻ đã sai lúc đầu.
      expect(session.remainingCount, 1);
      expect(session.currentCard!.word, 'one');
      expect(
        session.currentCard!.boxNumber,
        1,
        reason: 'Thẻ quay lại phải mang bản đã hạ về Hộp 1',
      );

      // Lần này trả lời đúng thì mới thật sự rời hàng đợi.
      final secondOutcome = session.answer(true);
      expect(secondOutcome.shouldRequeue, isFalse);
      expect(
        secondOutcome.updatedCard.boxNumber,
        1,
        reason: 'Sửa sai trong buổi không được lên hộp',
      );
      expect(session.isFinished, isTrue);
    });

    test(
      'Thẻ sai nhiều lần thì quay lại nhiều lần, buổi học chưa thể kết thúc',
      () {
        final session = StudySession(
          queue: [makeCard(id: 'aa', word: 'stubborn')],
          service: service,
          logIdFactory: sequentialLogIds(),
        );

        for (var attempt = 0; attempt < 3; attempt++) {
          session.answer(false);
          expect(
            session.isFinished,
            isFalse,
            reason: 'Còn thẻ sai thì buổi học chưa được kết thúc',
          );
          expect(session.remainingCount, 1);
        }

        session.answer(true);
        expect(session.isFinished, isTrue);
      },
    );

    test('Số liệu buổi học đếm đúng lượt trả lời và số thẻ', () {
      final session = StudySession(
        queue: [
          makeCard(id: 'aa', word: 'one'),
          makeCard(id: 'bb', word: 'two'),
        ],
        service: service,
        logIdFactory: sequentialLogIds(),
      );

      session.answer(false); // 'one' sai, xuống cuối
      session.answer(true); // 'two' đúng
      session.answer(true); // 'one' sửa được

      final stats = session.stats;
      expect(stats.totalAnswers, 3);
      expect(stats.correctAnswers, 2);
      expect(stats.wrongAnswers, 1);
      expect(stats.cardsCompleted, 2, reason: 'Có 2 thẻ khác nhau đã học xong');
      expect(stats.cardsLapsed, 1);
      expect(
        session.logs.length,
        3,
        reason: 'Mỗi lượt trả lời một dòng nhật ký',
      );
    });

    test('Gọi trả lời khi hàng đợi rỗng thì ném lỗi, không nuốt lặng', () {
      final session = StudySession(
        queue: const [],
        service: service,
        logIdFactory: sequentialLogIds(),
      );
      expect(() => session.answer(true), throwsStateError);
    });
  });

  group('3.5 — Dựng hàng đợi hôm nay', () {
    test('Thẻ hộp thấp luôn đứng trước thẻ hộp cao', () {
      final cards = [
        makeCard(id: 'e', boxNumber: 5),
        makeCard(id: 'a', boxNumber: 1),
        makeCard(id: 'd', boxNumber: 4),
        makeCard(id: 'b', boxNumber: 2),
        makeCard(id: 'c', boxNumber: 3),
      ];

      final queue = service.buildTodayQueue(cards);

      expect(queue.map((card) => card.boxNumber).toList(), [1, 2, 3, 4, 5]);
    });

    test('Không làm mất hay nhân bản thẻ nào', () {
      final cards = List.generate(
        30,
        (index) => makeCard(id: 'card-$index', boxNumber: (index % 5) + 1),
      );

      final queue = service.buildTodayQueue(cards);

      expect(queue.length, 30);
      expect(queue.map((card) => card.id).toSet().length, 30);
    });

    test('Thứ tự bên trong cùng một hộp có xáo trộn', () {
      // Xáo trộn là ngẫu nhiên nên không thể khẳng định một thứ tự cụ thể. Cách
      // kiểm chứng hợp lý: với 40 thẻ cùng hộp, xác suất trộn ra đúng y nguyên
      // thứ tự ban đầu là gần như bằng không.
      final cards = List.generate(
        40,
        (index) => makeCard(id: 'card-$index', boxNumber: 1),
      );

      final queue = service.buildTodayQueue(cards);

      expect(
        queue.map((card) => card.id).toList(),
        isNot(equals(cards.map((card) => card.id).toList())),
      );
    });

    test('Danh sách rỗng thì trả về hàng đợi rỗng', () {
      expect(service.buildTodayQueue(const []), isEmpty);
    });
  });

  group('3.6 — Giới hạn từ mới mỗi ngày', () {
    final now = DateTime(2025, 5, 4, 9, 0);
    final today = DateTime(2025, 5, 4);

    List<Flashcard> library(int count) => List.generate(
      count,
      (index) => makeCard(
        id: 'lib-$index',
        word: 'word$index',
        boxNumber: 1,
        isActive: false,
      ),
    );

    test('Mặc định cho phép 20 thẻ mỗi ngày', () {
      final result = service.activateNewCards(
        libraryCards: library(50),
        settings: const AppSettings(),
        now: now,
      );

      expect(result.activatedCards.length, 20);
      expect(result.remainingQuota, 0);
      expect(result.updatedSettings.activatedCountToday, 20);
      expect(result.updatedSettings.lastActivationDate, today);
    });

    test('Thẻ kích hoạt vào Hộp 1 và đến hạn ngay hôm nay', () {
      final result = service.activateNewCards(
        libraryCards: library(3),
        settings: const AppSettings(),
        now: now,
      );

      for (final card in result.activatedCards) {
        expect(card.isActive, isTrue);
        expect(card.boxNumber, 1);
        expect(
          card.nextReviewDate,
          today,
          reason: 'Chọn từ mới xong phải học được ngay trong ngày',
        );
        expect(card.updatedAt, now);
      }
    });

    test('Kích hoạt nhiều lần trong cùng ngày thì cộng dồn vào hạn mức', () {
      final first = service.activateNewCards(
        libraryCards: library(30),
        settings: const AppSettings(),
        requestedCount: 12,
        now: now,
      );
      expect(first.activatedCards.length, 12);
      expect(first.remainingQuota, 8);

      final second = service.activateNewCards(
        libraryCards: library(30),
        settings: first.updatedSettings,
        now: now.add(const Duration(hours: 3)),
      );

      expect(second.activatedCards.length, 8, reason: 'Chỉ còn 8 suất');
      expect(second.remainingQuota, 0);
      expect(second.updatedSettings.activatedCountToday, 20);
    });

    test('Hết suất thì không kích hoạt thêm thẻ nào', () {
      final exhausted = AppSettings(
        lastActivationDate: today,
        activatedCountToday: 20,
      );

      final result = service.activateNewCards(
        libraryCards: library(10),
        settings: exhausted,
        now: now,
      );

      expect(result.activatedCards, isEmpty);
      expect(
        result.updatedSettings.activatedCountToday,
        20,
        reason: 'Bộ đếm phải giữ nguyên, không bị đặt lại',
      );
    });

    test('Sang ngày mới thì hạn mức tự đầy lại', () {
      final yesterday = AppSettings(
        lastActivationDate: today,
        activatedCountToday: 20,
      );

      final result = service.activateNewCards(
        libraryCards: library(30),
        settings: yesterday,
        now: DateTime(2025, 5, 5, 8, 0),
      );

      expect(result.activatedCards.length, 20);
      expect(result.updatedSettings.activatedCountToday, 20);
      expect(result.updatedSettings.lastActivationDate, DateTime(2025, 5, 5));
    });

    test('Thư viện ít thẻ hơn hạn mức thì chỉ lấy đúng số có', () {
      final result = service.activateNewCards(
        libraryCards: library(5),
        settings: const AppSettings(),
        now: now,
      );

      expect(result.activatedCards.length, 5);
      expect(result.remainingQuota, 15);
    });

    test('Người học tự hạ hạn mức xuống thấp thì suất còn lại không âm', () {
      final settings = AppSettings(
        newCardsPerDay: 5,
        lastActivationDate: today,
        activatedCountToday: 12,
      );

      expect(settings.remainingQuotaOn(today), 0);
      final result = service.activateNewCards(
        libraryCards: library(10),
        settings: settings,
        now: now,
      );
      expect(result.activatedCards, isEmpty);
    });
  });
}
