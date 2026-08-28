import 'package:flutter_test/flutter_test.dart';
import 'package:leitner_app/models/flashcard.dart';
import 'package:leitner_app/models/session_state.dart';
import 'package:leitner_app/providers/deck_provider.dart';
import 'package:leitner_app/providers/study_provider.dart';
import 'package:leitner_app/services/leitner_service.dart';

import 'fakes/fake_repositories.dart';

Flashcard makeCard({
  required String id,
  String word = 'word',
  int boxNumber = 1,
  DateTime? nextReviewDate,
}) {
  final epoch = DateTime(2025, 1, 1);
  return Flashcard(
    id: id,
    word: word,
    phonetic: '/w/',
    meaning: 'nghĩa',
    exampleSentence: 'Một câu ví dụ.',
    boxNumber: boxNumber,
    nextReviewDate: nextReviewDate ?? epoch,
    isActive: true,
    createdAt: epoch,
    updatedAt: epoch,
  );
}

void main() {
  late FakeCardRepository cards;
  late FakeStudyLogRepository logs;
  late FakeSettingsRepository settings;
  late FakeSessionStateRepository sessions;

  StudyProvider makeStudy() => StudyProvider(
    cardRepository: cards,
    logRepository: logs,
    sessionStateRepository: sessions,
    leitner: LeitnerService(),
  );

  DeckProvider makeDeck() => DeckProvider(
    cardRepository: cards,
    logRepository: logs,
    settingsRepository: settings,
    sessionStateRepository: sessions,
    leitner: LeitnerService(),
  );

  setUp(() {
    cards = FakeCardRepository();
    logs = FakeStudyLogRepository();
    settings = FakeSettingsRepository();
    sessions = FakeSessionStateRepository();
  });

  group('Lưu trạng thái buổi học', () {
    test('Bắt đầu buổi thì trạng thái được lưu ngay', () async {
      final study = makeStudy();
      await study.start([
        makeCard(id: 'a'),
        makeCard(id: 'b'),
        makeCard(id: 'c'),
      ]);

      final saved = sessions.current;
      expect(saved, isNotNull);
      expect(saved!.queueCardIds, ['a', 'b', 'c']);
      expect(saved.initialCount, 3);
      expect(saved.completedCardIds, isEmpty);
    });

    test(
      'Mỗi lượt trả lời đều cập nhật trạng thái, không đợi cuối buổi',
      () async {
        final study = makeStudy();
        await study.start([makeCard(id: 'a'), makeCard(id: 'b')]);

        await study.answer(true);

        final saved = sessions.current;
        expect(saved!.queueCardIds, ['b'], reason: 'Thẻ a đã rời hàng đợi');
        expect(saved.completedCardIds, ['a']);
        expect(saved.correctAnswers, 1);
      },
    );

    test('Trả lời sai thì thẻ nằm ở CUỐI hàng đợi đã lưu', () async {
      final study = makeStudy();
      await study.start([
        makeCard(id: 'a'),
        makeCard(id: 'b'),
        makeCard(id: 'c'),
      ]);

      await study.answer(false);

      final saved = sessions.current;
      expect(saved!.queueCardIds, [
        'b',
        'c',
        'a',
      ], reason: 'Thứ tự là phần quan trọng nhất của ảnh chụp');
      expect(saved.failedCardIds, ['a']);
      expect(saved.wrongAnswers, 1);
    });

    test('Buổi học kết thúc thì trạng thái bị xoá', () async {
      final study = makeStudy();
      await study.start([makeCard(id: 'a')]);
      expect(sessions.current, isNotNull);

      await study.answer(true);

      expect(study.status, StudyStatus.finished);
      expect(
        sessions.current,
        isNull,
        reason: 'Xong buổi thì phải xoá ảnh chụp',
      );
    });

    test('Thoát giữa chừng thì trạng thái vẫn còn nguyên', () async {
      final study = makeStudy();
      await study.start([makeCard(id: 'a'), makeCard(id: 'b')]);
      await study.answer(true);

      // reset() mô phỏng người học rời màn hình Học mà chưa xong buổi.
      study.reset();

      expect(
        sessions.current,
        isNotNull,
        reason: 'Rời màn hình không được làm mất buổi dở',
      );
      expect(sessions.current!.queueCardIds, ['b']);
    });
  });

  group('Khôi phục buổi học dở', () {
    test('Dựng lại đúng hàng đợi theo thứ tự đã lưu', () async {
      final queue = [
        makeCard(id: 'a', word: 'one'),
        makeCard(id: 'b', word: 'two'),
        makeCard(id: 'c', word: 'three'),
      ];
      cards.seed(queue);

      final study = makeStudy();
      await study.restore(
        SessionState(
          queueCardIds: ['c', 'a'],
          failedCardIds: const [],
          completedCardIds: const ['b'],
          initialCount: 3,
          correctAnswers: 1,
          wrongAnswers: 0,
          startedAt: DateTime(2025, 5, 10, 9),
        ),
        {for (final card in queue) card.id: card},
      );

      expect(study.status, StudyStatus.studying);
      expect(study.currentCard!.word, 'three');
      expect(study.remainingCount, 2);
      expect(study.initialCount, 3);
      expect(study.stats!.cardsCompleted, 1);
    });

    test(
      'Thẻ từng sai vẫn giữ luật không được lên hộp sau khi khôi phục',
      () async {
        // Đây là lý do phải lưu failedCardIds. Không lưu thì sau khi khôi phục,
        // thẻ từng sai bị coi như chưa sai và lượt đúng kế tiếp lại cho nó lên hộp.
        final card = makeCard(id: 'a', boxNumber: 1);
        cards.seed([card]);

        final study = makeStudy();
        await study.restore(
          SessionState(
            queueCardIds: const ['a'],
            failedCardIds: const ['a'],
            completedCardIds: const [],
            initialCount: 1,
            correctAnswers: 0,
            wrongAnswers: 1,
            startedAt: DateTime(2025, 5, 10, 9),
          ),
          {'a': card},
        );

        await study.answer(true);

        expect(
          cards.saved.single.boxNumber,
          1,
          reason: 'Thẻ từng sai thì lượt đúng không được lên hộp',
        );
      },
    );

    test('Thẻ đã bị xoá khỏi kho thì bỏ qua, không làm hỏng cả buổi', () async {
      final remaining = makeCard(id: 'b', word: 'two');
      cards.seed([remaining]);

      final study = makeStudy();
      await study.restore(
        SessionState(
          queueCardIds: const ['a', 'b'], // thẻ 'a' đã bị xoá ở Thư viện
          failedCardIds: const [],
          completedCardIds: const [],
          initialCount: 2,
          correctAnswers: 0,
          wrongAnswers: 0,
          startedAt: DateTime(2025, 5, 10, 9),
        ),
        {'b': remaining},
      );

      expect(study.status, StudyStatus.studying);
      expect(study.remainingCount, 1);
      expect(study.currentCard!.word, 'two');
    });

    test('Không còn thẻ nào hợp lệ thì bỏ buổi dở và xoá trạng thái', () async {
      final study = makeStudy();
      await study.restore(
        SessionState(
          queueCardIds: const ['da-xoa'],
          failedCardIds: const [],
          completedCardIds: const [],
          initialCount: 1,
          correctAnswers: 0,
          wrongAnswers: 0,
          startedAt: DateTime(2025, 5, 10, 9),
        ),
        const {},
      );

      expect(study.status, StudyStatus.idle);
      expect(sessions.clearCount, greaterThan(0));
    });
  });

  group('Phát hiện buổi dở khi mở app', () {
    SessionState stateStartedAt(DateTime when) => SessionState(
      queueCardIds: const ['a'],
      failedCardIds: const [],
      completedCardIds: const [],
      initialCount: 2,
      correctAnswers: 1,
      wrongAnswers: 0,
      startedAt: when,
    );

    test('Buổi dở của hôm nay thì được nhận ra', () async {
      final today = DateTime(2025, 5, 10, 20);
      sessions.current = stateStartedAt(DateTime(2025, 5, 10, 8));

      final deck = makeDeck();
      await deck.refresh(now: today);

      expect(deck.hasResumableSession, isTrue);
      expect(deck.resumableSession!.queueCardIds, ['a']);
    });

    test('Buổi dở từ ngày trước bị tự xoá, không hỏi han', () async {
      final today = DateTime(2025, 5, 10, 8);
      sessions.current = stateStartedAt(DateTime(2025, 5, 9, 21));

      final deck = makeDeck();
      await deck.refresh(now: today);

      expect(deck.hasResumableSession, isFalse);
      expect(sessions.current, isNull, reason: 'Buổi cũ phải bị dọn');
    });

    test('Ảnh chụp còn sót với hàng đợi rỗng thì cũng bị dọn', () async {
      final today = DateTime(2025, 5, 10, 20);
      sessions.current = SessionState(
        queueCardIds: const [],
        failedCardIds: const [],
        completedCardIds: const ['a'],
        initialCount: 1,
        correctAnswers: 1,
        wrongAnswers: 0,
        startedAt: DateTime(2025, 5, 10, 8),
      );

      final deck = makeDeck();
      await deck.refresh(now: today);

      expect(deck.hasResumableSession, isFalse);
      expect(sessions.current, isNull);
    });

    test('Không có buổi dở thì không có gì để hỏi', () async {
      final deck = makeDeck();
      await deck.refresh(now: DateTime(2025, 5, 10));
      expect(deck.hasResumableSession, isFalse);
    });

    test('Chọn bắt đầu lại thì buổi dở bị bỏ', () async {
      final today = DateTime(2025, 5, 10, 20);
      sessions.current = stateStartedAt(DateTime(2025, 5, 10, 8));

      final deck = makeDeck();
      await deck.refresh(now: today);
      expect(deck.hasResumableSession, isTrue);

      await deck.discardResumableSession(now: today);

      expect(deck.hasResumableSession, isFalse);
      expect(sessions.current, isNull);
    });
  });
}
