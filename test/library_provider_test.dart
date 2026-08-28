import 'package:flutter_test/flutter_test.dart';
import 'package:leitner_app/models/flashcard.dart';
import 'package:leitner_app/providers/library_provider.dart';

import 'fakes/fake_repositories.dart';

Flashcard makeCard({
  required String id,
  required String word,
  String meaning = 'nghĩa',
  int boxNumber = 1,
  bool isActive = true,
}) {
  final epoch = DateTime(2025, 1, 1);
  return Flashcard(
    id: id,
    word: word,
    phonetic: '/w/',
    meaning: meaning,
    exampleSentence: 'Một câu ví dụ.',
    boxNumber: boxNumber,
    nextReviewDate: epoch,
    isActive: isActive,
    createdAt: epoch,
    updatedAt: epoch,
  );
}

void main() {
  late FakeCardRepository cards;
  late LibraryProvider library;

  setUp(() async {
    cards = FakeCardRepository();
    cards.seed([
      makeCard(id: '1', word: 'apple', meaning: 'quả táo', boxNumber: 1),
      makeCard(id: '2', word: 'Banana', meaning: 'quả chuối', boxNumber: 3),
      makeCard(
        id: '3',
        word: 'cherry',
        meaning: 'quả anh đào',
        boxNumber: 5,
        isActive: false,
      ),
      makeCard(id: '4', word: 'date', meaning: 'quả chà là', isActive: false),
    ]);
    library = LibraryProvider(cardRepository: cards);
    await library.refresh();
  });

  group('Tìm kiếm và lọc', () {
    test('Mặc định hiện tất cả, sắp theo bảng chữ cái', () {
      expect(library.visibleCards.map((card) => card.word).toList(), [
        'apple',
        'Banana',
        'cherry',
        'date',
      ]);
    });

    test('Tìm theo từ tiếng Anh, không phân biệt hoa thường', () {
      library.setSearchTerm('BAN');
      expect(library.visibleCards.map((card) => card.word).toList(), [
        'Banana',
      ]);
    });

    test('Tìm được cả theo nghĩa tiếng Việt', () {
      // Người học nhớ nghĩa trước khi nhớ mặt chữ là chuyện thường.
      library.setSearchTerm('anh đào');
      expect(library.visibleCards.map((card) => card.word).toList(), [
        'cherry',
      ]);
    });

    test('Lọc theo hộp', () {
      library.setBoxFilter(3);
      expect(library.visibleCards.map((card) => card.id).toList(), ['2']);
    });

    test('Lọc theo trạng thái kích hoạt', () {
      library.setActivationFilter(ActivationFilter.inactive);
      expect(library.visibleCards.map((card) => card.word).toList(), [
        'cherry',
        'date',
      ]);

      library.setActivationFilter(ActivationFilter.active);
      expect(library.visibleCards.map((card) => card.word).toList(), [
        'apple',
        'Banana',
      ]);
    });

    test('Các bộ lọc chồng lên nhau', () {
      library.setActivationFilter(ActivationFilter.inactive);
      library.setSearchTerm('quả');
      library.setBoxFilter(5);
      expect(library.visibleCards.map((card) => card.id).toList(), ['3']);
    });

    test('Không khớp gì thì trả về danh sách rỗng, không phải toàn bộ', () {
      library.setSearchTerm('khong-co-tu-nao-nhu-vay');
      expect(library.visibleCards, isEmpty);
    });
  });

  group('Chọn nhiều thẻ', () {
    test('Chạm để chọn, chạm lại để bỏ chọn', () {
      library.toggleSelection('1');
      expect(library.selectedIds, {'1'});
      library.toggleSelection('1');
      expect(library.selectedIds, isEmpty);
    });

    test('Chọn tất cả chỉ áp dụng cho các thẻ đang hiện', () {
      library.setActivationFilter(ActivationFilter.inactive);
      library.toggleSelectAllVisible();
      expect(library.selectedIds, {'3', '4'});
    });

    test('Bấm chọn tất cả lần nữa thì bỏ chọn hết', () {
      library.toggleSelectAllVisible();
      expect(library.selectedIds.length, 4);
      library.toggleSelectAllVisible();
      expect(library.selectedIds, isEmpty);
    });

    test('Chỉ đếm thẻ chưa kích hoạt khi đưa vào Hộp 1', () {
      library.toggleSelectAllVisible();
      expect(library.selectedInactiveCards.map((card) => card.id).toSet(), {
        '3',
        '4',
      }, reason: 'Thẻ đang học thì không kích hoạt lại');
    });

    test('Thẻ bị xoá thì tự rời khỏi vùng chọn', () async {
      library.toggleSelection('1');
      await library.deleteCard('1');
      expect(library.selectedIds, isEmpty);
      expect(library.totalCount, 3);
    });
  });

  group('Thêm, sửa, xoá thẻ', () {
    test('Thẻ mới nằm im trong thư viện, chưa vào vòng học', () async {
      final card = await library.addCard(
        word: '  refund  ',
        phonetic: ' /ˈriːfʌnd/ ',
        meaning: ' hoàn tiền ',
        exampleSentence: ' The airline promised a full refund. ',
      );

      expect(card.isActive, isFalse, reason: 'Phải chờ người học kích hoạt');
      expect(card.boxNumber, 1);
      expect(card.word, 'refund', reason: 'Khoảng trắng thừa phải bị cắt');
      expect(card.phonetic, '/ˈriːfʌnd/');
      expect(library.totalCount, 5);
    });

    test('Đường dẫn ảnh để trống thì lưu thành null', () async {
      final card = await library.addCard(
        word: 'x',
        phonetic: '/x/',
        meaning: 'y',
        exampleSentence: 'z',
        imagePath: '   ',
      );
      expect(card.imagePath, isNull);
    });

    test('Sửa nội dung không đụng tới hộp và lịch ôn', () async {
      final before = (await cards.getById('2'))!;
      await library.updateCard(
        before,
        word: 'banana',
        phonetic: '/bəˈnænə/',
        meaning: 'quả chuối chín',
        exampleSentence: 'He ate a banana after the run.',
        now: DateTime(2025, 6, 1),
      );

      final after = (await cards.getById('2'))!;
      expect(after.meaning, 'quả chuối chín');
      expect(after.boxNumber, before.boxNumber, reason: 'Hộp phải giữ nguyên');
      expect(after.nextReviewDate, before.nextReviewDate);
      expect(
        after.updatedAt,
        DateTime(2025, 6, 1),
        reason: 'Sửa nội dung phải đóng dấu thời gian mới',
      );
    });

    test('Xoá được nhiều thẻ cùng lúc', () async {
      library.toggleSelection('1');
      library.toggleSelection('3');
      final removed = await library.deleteSelected();

      expect(removed, 2);
      expect(library.totalCount, 2);
      expect(library.selectedIds, isEmpty);
    });
  });
}
