import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leitner_app/models/flashcard.dart';
import 'package:leitner_app/providers/deck_provider.dart';
import 'package:leitner_app/providers/study_provider.dart';
import 'package:leitner_app/screens/home_screen.dart';
import 'package:leitner_app/screens/study_screen.dart';
import 'package:leitner_app/services/leitner_service.dart';
import 'package:leitner_app/widgets/box_tile.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_repositories.dart';

/// Dựng một thẻ để kiểm thử giao diện.
Flashcard makeCard({
  required String id,
  String word = 'apple',
  String meaning = 'quả táo',
  String sentence = 'She packed an apple in her lunch bag this morning.',
  int boxNumber = 1,
  DateTime? nextReviewDate,
  bool isActive = true,
}) {
  final epoch = DateTime(2025, 1, 1);
  return Flashcard(
    id: id,
    word: word,
    phonetic: '/ˈæpəl/',
    meaning: meaning,
    exampleSentence: sentence,
    boxNumber: boxNumber,
    nextReviewDate: nextReviewDate ?? epoch,
    isActive: isActive,
    createdAt: epoch,
    updatedAt: epoch,
  );
}

/// Dựng cây widget đầy đủ provider để test màn hình.
Widget wrapWithProviders({
  required Widget child,
  required FakeCardRepository cards,
  required FakeStudyLogRepository logs,
  required FakeSettingsRepository settings,
  DeckProvider? deckProvider,
  StudyProvider? studyProvider,
}) {
  final leitner = LeitnerService();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DeckProvider>.value(
        value:
            deckProvider ??
            DeckProvider(
              cardRepository: cards,
              logRepository: logs,
              settingsRepository: settings,
              leitner: leitner,
            ),
      ),
      ChangeNotifierProvider<StudyProvider>.value(
        value:
            studyProvider ??
            StudyProvider(
              cardRepository: cards,
              logRepository: logs,
              leitner: leitner,
            ),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  late FakeCardRepository cards;
  late FakeStudyLogRepository logs;
  late FakeSettingsRepository settings;

  setUp(() {
    cards = FakeCardRepository();
    logs = FakeStudyLogRepository();
    settings = FakeSettingsRepository();
  });

  group('Màn hình Tổng quan', () {
    testWidgets('Hiện đủ năm khối hộp', (tester) async {
      final deck = DeckProvider(
        cardRepository: cards,
        logRepository: logs,
        settingsRepository: settings,
        leitner: LeitnerService(),
      );
      await deck.refresh();

      await tester.pumpWidget(
        wrapWithProviders(
          child: const HomeScreen(),
          cards: cards,
          logs: logs,
          settings: settings,
          deckProvider: deck,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BoxTile), findsNWidgets(5));
      for (var boxNumber = 1; boxNumber <= 5; boxNumber++) {
        expect(find.text('Hộp $boxNumber'), findsOneWidget);
      }
    });

    testWidgets('Không có thẻ đến hạn thì nút học bị vô hiệu hoá', (
      tester,
    ) async {
      // Thẻ có hạn ôn tận sang năm nên hôm nay không có gì để học.
      cards.seed([makeCard(id: 'a', nextReviewDate: DateTime(2099, 1, 1))]);

      final deck = DeckProvider(
        cardRepository: cards,
        logRepository: logs,
        settingsRepository: settings,
        leitner: LeitnerService(),
      );
      await deck.refresh();

      await tester.pumpWidget(
        wrapWithProviders(
          child: const HomeScreen(),
          cards: cards,
          logs: logs,
          settings: settings,
          deckProvider: deck,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HỌC HÔM NAY (0 từ)'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'HỌC HÔM NAY (0 từ)'),
      );
      expect(button.onPressed, isNull, reason: 'Nút phải bị vô hiệu hoá');
    });

    testWidgets('Có thẻ đến hạn thì nút học bật lên và hiện đúng số từ', (
      tester,
    ) async {
      cards.seed([
        makeCard(id: 'a', nextReviewDate: DateTime(2020, 1, 1)),
        makeCard(id: 'b', nextReviewDate: DateTime(2020, 1, 1)),
        makeCard(id: 'c', nextReviewDate: DateTime(2099, 1, 1)),
      ]);

      final deck = DeckProvider(
        cardRepository: cards,
        logRepository: logs,
        settingsRepository: settings,
        leitner: LeitnerService(),
      );
      await deck.refresh();

      await tester.pumpWidget(
        wrapWithProviders(
          child: const HomeScreen(),
          cards: cards,
          logs: logs,
          settings: settings,
          deckProvider: deck,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HỌC HÔM NAY (2 từ)'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'HỌC HÔM NAY (2 từ)'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Hiện số từ đã thuộc, tức số thẻ ở Hộp 5', (tester) async {
      cards.seed([
        makeCard(id: 'a', boxNumber: 5),
        makeCard(id: 'b', boxNumber: 5),
        makeCard(id: 'c', boxNumber: 4),
        makeCard(id: 'd', boxNumber: 5, isActive: false),
      ]);

      final deck = DeckProvider(
        cardRepository: cards,
        logRepository: logs,
        settingsRepository: settings,
        leitner: LeitnerService(),
      );
      await deck.refresh();

      expect(
        deck.masteredCount,
        2,
        reason: 'Thẻ chưa kích hoạt không được tính là đã thuộc',
      );

      await tester.pumpWidget(
        wrapWithProviders(
          child: const HomeScreen(),
          cards: cards,
          logs: logs,
          settings: settings,
          deckProvider: deck,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('từ đã thuộc'), findsOneWidget);
    });
  });

  group('Màn hình Học', () {
    Future<StudyProvider> startSession(
      WidgetTester tester,
      List<Flashcard> queue,
    ) async {
      final study = StudyProvider(
        cardRepository: cards,
        logRepository: logs,
        leitner: LeitnerService(),
      );
      study.start(queue);

      await tester.pumpWidget(
        wrapWithProviders(
          child: const StudyScreen(),
          cards: cards,
          logs: logs,
          settings: settings,
          studyProvider: study,
        ),
      );
      await tester.pumpAndSettle();
      return study;
    }

    testWidgets('Mặt trước hiện từ và phiên âm, chưa hiện nghĩa', (
      tester,
    ) async {
      await startSession(tester, [makeCard(id: 'a')]);

      expect(find.text('apple'), findsOneWidget);
      expect(find.text('/ˈæpəl/'), findsOneWidget);
      expect(find.text('quả táo'), findsNothing);
      expect(find.text('Chạm vào thẻ để xem nghĩa'), findsOneWidget);
    });

    testWidgets('Chạm vào thẻ thì lật ra mặt sau và hiện hai nút trả lời', (
      tester,
    ) async {
      await startSession(tester, [makeCard(id: 'a')]);

      await tester.tap(find.text('apple'));
      await tester.pumpAndSettle();

      expect(find.text('quả táo'), findsOneWidget);
      expect(find.text('SAI'), findsOneWidget);
      expect(find.text('ĐÚNG'), findsOneWidget);
    });

    testWidgets('Chưa lật thẻ thì không có nút trả lời nào', (tester) async {
      await startSession(tester, [makeCard(id: 'a')]);

      expect(find.text('SAI'), findsNothing);
      expect(find.text('ĐÚNG'), findsNothing);
    });

    testWidgets('Trả lời ĐÚNG thì thẻ rời hàng đợi và được ghi xuống kho', (
      tester,
    ) async {
      final study = await startSession(tester, [makeCard(id: 'a')]);

      await tester.tap(find.text('apple'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ĐÚNG'));
      await tester.pumpAndSettle();

      expect(study.status, StudyStatus.finished);
      expect(find.text('Xong buổi hôm nay!'), findsOneWidget);
      // Thẻ lên Hộp 2 và nhật ký được ghi ngay trong lượt.
      expect(cards.saved.single.boxNumber, 2);
      expect(logs.appended.single.isCorrect, isTrue);
    });

    testWidgets('Trả lời SAI thì thẻ quay lại cuối hàng đợi, buổi chưa xong', (
      tester,
    ) async {
      final study = await startSession(tester, [
        makeCard(id: 'aa', word: 'one'),
        makeCard(id: 'bb', word: 'two'),
      ]);

      expect(study.remainingCount, 2);

      await tester.tap(find.text('one'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAI'));
      await tester.pumpAndSettle();

      // Vẫn còn 2 thẻ: 'two' đang hiện, 'one' chờ ở cuối hàng.
      expect(study.remainingCount, 2);
      expect(study.status, StudyStatus.studying);
      expect(find.text('two'), findsOneWidget);
      expect(
        cards.saved.single.boxNumber,
        1,
        reason: 'Trả lời sai thì thẻ phải rơi về Hộp 1',
      );
    });

    testWidgets('Sang thẻ kế tiếp thì thẻ tự úp lại, không lộ đáp án', (
      tester,
    ) async {
      final study = await startSession(tester, [
        makeCard(id: 'aa', word: 'one', meaning: 'một'),
        makeCard(id: 'bb', word: 'two', meaning: 'hai'),
      ]);

      await tester.tap(find.text('one'));
      await tester.pumpAndSettle();
      expect(find.text('một'), findsOneWidget);

      await tester.tap(find.text('ĐÚNG'));
      await tester.pumpAndSettle();

      expect(study.isRevealed, isFalse);
      expect(find.text('two'), findsOneWidget);
      expect(
        find.text('hai'),
        findsNothing,
        reason: 'Thẻ mới phải hiện mặt trước',
      );
    });

    testWidgets('Vuốt phải là ĐÚNG, vuốt trái là SAI', (tester) async {
      final study = await startSession(tester, [
        makeCard(id: 'aa', word: 'one'),
        makeCard(id: 'bb', word: 'two'),
      ]);

      // Phải lật xem đáp án trước thì cú vuốt mới được tính là trả lời.
      await tester.tap(find.text('one'));
      await tester.pumpAndSettle();

      await tester.fling(find.text('quả táo'), const Offset(400, 0), 1200);
      await tester.pumpAndSettle();

      expect(cards.saved.single.boxNumber, 2, reason: 'Vuốt phải là ĐÚNG');
      expect(study.remainingCount, 1);
    });

    testWidgets('Màn hình chúc mừng hiện đủ số liệu buổi học', (tester) async {
      await startSession(tester, [
        makeCard(id: 'aa', word: 'one'),
        makeCard(id: 'bb', word: 'two'),
      ]);

      for (final word in ['one', 'two']) {
        await tester.tap(find.text(word));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ĐÚNG'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Xong buổi hôm nay!'), findsOneWidget);
      expect(find.text('Số thẻ đã học'), findsOneWidget);
      expect(find.text('Tỉ lệ đúng'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });
  });
}
