import 'package:flutter_test/flutter_test.dart';
import 'package:leitner_app/models/flashcard.dart';
import 'package:leitner_app/providers/deck_provider.dart';
import 'package:leitner_app/providers/library_provider.dart';
import 'package:leitner_app/services/leitner_service.dart';

import 'fakes/fake_repositories.dart';

/// Kho thẻ giả có thể làm chậm thao tác ghi, để mô phỏng máy yếu.
class SlowCardRepository extends FakeCardRepository {
  Duration writeDelay = Duration.zero;

  /// Số lần [saveAll] thực sự được gọi. Dùng để bắt lỗi bấm chồng.
  int saveAllCount = 0;

  @override
  Future<void> saveAll(List<Flashcard> cards) async {
    saveAllCount++;
    if (writeDelay > Duration.zero) await Future.delayed(writeDelay);
    await super.saveAll(cards);
  }
}

Flashcard makeCard({required String id, bool isActive = false}) {
  final epoch = DateTime(2025, 1, 1);
  return Flashcard(
    id: id,
    word: 'w$id',
    phonetic: '/w/',
    meaning: 'nghĩa',
    exampleSentence: 'Một câu ví dụ.',
    boxNumber: 1,
    nextReviewDate: epoch,
    isActive: isActive,
    createdAt: epoch,
    updatedAt: epoch,
  );
}

void main() {
  late SlowCardRepository cards;
  late FakeStudyLogRepository logs;
  late FakeSettingsRepository settings;
  late FakeSessionStateRepository sessions;

  DeckProvider makeDeck() => DeckProvider(
    cardRepository: cards,
    logRepository: logs,
    settingsRepository: settings,
    sessionStateRepository: sessions,
    leitner: LeitnerService(),
  );

  setUp(() {
    cards = SlowCardRepository();
    logs = FakeStudyLogRepository();
    settings = FakeSettingsRepository();
    sessions = FakeSessionStateRepository();
    cards.seed([for (var i = 0; i < 15; i++) makeCard(id: 'lib-$i')]);
  });

  group('Cờ báo đang xử lý ở DeckProvider', () {
    test('Mặc định không bận', () {
      expect(makeDeck().isBusy, isFalse);
    });

    test('Bật lên trong lúc kích hoạt thẻ, tắt khi xong', () async {
      cards.writeDelay = const Duration(milliseconds: 40);
      final deck = makeDeck();

      final future = deck.activateNewCards();
      // Chưa await: thao tác còn đang chạy nên cờ phải đang bật.
      expect(deck.isBusy, isTrue);

      await future;
      expect(deck.isBusy, isFalse);
    });

    test('Bấm chồng lần hai bị bỏ qua, không chạy thêm lượt ghi nào', () async {
      // Đây chính là lỗi thật: trên máy chậm, người dùng tưởng nút hỏng nên bấm
      // tiếp; mỗi lần bấm lại chạy thêm một lượt ghi và đọc lại toàn bộ kho,
      // càng bấm càng chậm.
      cards.writeDelay = const Duration(milliseconds: 50);
      final deck = makeDeck();

      final lanMot = deck.activateNewCards();
      final lanHai = deck.activateNewCards();
      final lanBa = deck.activateNewCards();

      final ketQua = await Future.wait([lanMot, lanHai, lanBa]);

      expect(ketQua[0], 15, reason: 'Lượt đầu phải kích hoạt đủ 15 thẻ');
      expect(ketQua[1], 0, reason: 'Lượt bấm chồng phải bị bỏ qua');
      expect(ketQua[2], 0, reason: 'Lượt bấm chồng phải bị bỏ qua');
      expect(
        cards.saveAllCount,
        1,
        reason: 'Chỉ được ghi xuống kho đúng MỘT lần',
      );
    });

    test('Cờ được tắt cả khi thao tác ném lỗi', () async {
      // Không có finally thì một lỗi giữa chừng sẽ khoá cứng nút mãi mãi.
      cards.failOnSaveAll = true;
      final deck = makeDeck();

      await expectLater(deck.activateNewCards(), throwsA(anything));
      expect(deck.isBusy, isFalse, reason: 'Lỗi rồi vẫn phải mở khoá nút');
    });

    test('Kích hoạt thẻ đã chọn cũng chặn bấm chồng', () async {
      cards.writeDelay = const Duration(milliseconds: 40);
      final deck = makeDeck();
      final chosen = [for (var i = 0; i < 5; i++) makeCard(id: 'lib-$i')];

      final lanMot = deck.activateSpecificCards(chosen);
      final lanHai = deck.activateSpecificCards(chosen);

      final ketQua = await Future.wait([lanMot, lanHai]);
      expect(ketQua[0].length, 5);
      expect(ketQua[1], isEmpty, reason: 'Lượt bấm chồng phải bị bỏ qua');
      expect(cards.saveAllCount, 1);
    });
  });

  group('Cờ báo đang xử lý ở LibraryProvider', () {
    test('Xoá nhiều thẻ: bấm chồng bị bỏ qua', () async {
      final library = LibraryProvider(cardRepository: cards);
      await library.refresh();
      library.toggleSelection('lib-0');
      library.toggleSelection('lib-1');

      final lanMot = library.deleteSelected();
      final lanHai = library.deleteSelected();
      final ketQua = await Future.wait([lanMot, lanHai]);

      expect(ketQua[0], 2);
      expect(ketQua[1], 0, reason: 'Lượt bấm chồng phải bị bỏ qua');
      expect(library.isBusy, isFalse);
    });
  });
}
