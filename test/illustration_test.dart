import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leitner_app/models/flashcard.dart';
import 'package:leitner_app/services/illustration_service.dart';
import 'package:leitner_app/widgets/card_faces.dart';
import 'package:leitner_app/widgets/illustration_progress.dart';
import 'package:provider/provider.dart';

Flashcard makeCard({
  required String id,
  String? imagePath,
  bool isActive = true,
}) {
  final epoch = DateTime(2025, 1, 1);
  return Flashcard(
    id: id,
    word: 'w$id',
    phonetic: '/w/',
    meaning: 'nghĩa',
    exampleSentence: 'Một câu ví dụ.',
    boxNumber: 1,
    nextReviewDate: epoch,
    imagePath: imagePath,
    isActive: isActive,
    createdAt: epoch,
    updatedAt: epoch,
  );
}

final Uri kGoc = Uri.parse('https://vi.du/leitner_app/');

void main() {
  group('Địa chỉ ảnh', () {
    final anh = IllustrationService(base: kGoc, tai: (_) async {});

    test('Thẻ không có ảnh thì trả về null', () {
      expect(anh.urlCho(makeCard(id: 'a')), isNull);
      expect(anh.urlCho(makeCard(id: 'b', imagePath: '')), isNull);
      expect(anh.urlCho(makeCard(id: 'c', imagePath: '   ')), isNull);
    });

    test('Đường dẫn tương đối được ghép vào gốc của app', () {
      expect(
        anh.urlCho(makeCard(id: 'a', imagePath: 'anh/apple.webp')).toString(),
        'https://vi.du/leitner_app/anh/apple.webp',
      );
    });

    test('Địa chỉ đầy đủ thì giữ nguyên', () {
      expect(
        anh
            .urlCho(makeCard(id: 'a', imagePath: 'https://khac/x.webp'))
            .toString(),
        'https://khac/x.webp',
      );
    });
  });

  group('Chỉ tải ảnh của thẻ ĐÃ KÍCH HOẠT', () {
    test('Thẻ trong thư viện chưa kích hoạt thì không tải', () async {
      final daGoi = <String>[];
      final anh = IllustrationService(
        base: kGoc,
        tai: (url) async => daGoi.add(url.toString()),
      );

      await anh.dongBo([
        makeCard(id: 'a', imagePath: 'anh/a.webp', isActive: true),
        makeCard(id: 'b', imagePath: 'anh/b.webp', isActive: false),
        makeCard(id: 'c', imagePath: 'anh/c.webp', isActive: false),
      ]);

      expect(
        daGoi,
        ['https://vi.du/leitner_app/anh/a.webp'],
        reason:
            'Đây chính là chỗ giữ cho lượng tải nhỏ. Tải cả thẻ chưa kích hoạt '
            'là quay về đúng bài toán 105 MB đã tránh.',
      );
      expect(anh.tong, 1);
      expect(anh.daTai, 1);
    });

    test('Thẻ không có ảnh không được tính vào tổng', () async {
      final anh = IllustrationService(base: kGoc, tai: (_) async {});
      await anh.dongBo([
        makeCard(id: 'a', imagePath: 'anh/a.webp'),
        makeCard(id: 'b'),
        makeCard(id: 'c', imagePath: ''),
      ]);
      expect(anh.tong, 1);
    });

    test('Gọi lại lần hai không tải lại ảnh đã xong', () async {
      var soLan = 0;
      final anh = IllustrationService(base: kGoc, tai: (_) async => soLan++);
      final the = [
        makeCard(id: 'a', imagePath: 'anh/a.webp'),
        makeCard(id: 'b', imagePath: 'anh/b.webp'),
      ];

      await anh.dongBo(the);
      expect(soLan, 2);

      await anh.dongBo(the);
      expect(soLan, 2, reason: 'Ảnh đã có rồi thì không được tải lại');
      expect(anh.daTai, 2);
    });

    test('Kích hoạt thêm thẻ thì chỉ tải phần mới', () async {
      final daGoi = <String>[];
      final anh = IllustrationService(
        base: kGoc,
        tai: (url) async => daGoi.add(url.pathSegments.last),
      );

      await anh.dongBo([makeCard(id: 'a', imagePath: 'anh/a.webp')]);
      await anh.dongBo([
        makeCard(id: 'a', imagePath: 'anh/a.webp'),
        makeCard(id: 'b', imagePath: 'anh/b.webp'),
      ]);

      expect(daGoi, ['a.webp', 'b.webp']);
      expect(anh.tong, 2);
      expect(anh.daTai, 2);
    });
  });

  group('Ảnh hỏng không được cản việc học', () {
    test('Một ảnh lỗi thì các ảnh còn lại vẫn tải tiếp', () async {
      final anh = IllustrationService(
        base: kGoc,
        tai: (url) async {
          if (url.toString().endsWith('b.webp')) {
            throw Exception('404');
          }
        },
      );

      await anh.dongBo([
        makeCard(id: 'a', imagePath: 'anh/a.webp'),
        makeCard(id: 'b', imagePath: 'anh/b.webp'),
        makeCard(id: 'c', imagePath: 'anh/c.webp'),
      ]);

      expect(anh.tong, 3);
      expect(anh.daTai, 2);
      expect(anh.soHong, 1);
      expect(anh.dangTai, isFalse);
    });

    test('Ảnh đã hỏng không bị thử lại mãi', () async {
      var soLan = 0;
      final anh = IllustrationService(
        base: kGoc,
        tai: (_) async {
          soLan++;
          throw Exception('404');
        },
      );
      final the = [makeCard(id: 'a', imagePath: 'anh/a.webp')];

      await anh.dongBo(the);
      await anh.dongBo(the);
      await anh.dongBo(the);

      expect(soLan, 1, reason: 'Thử lại vô hạn sẽ đốt pin và băng thông');
    });
  });

  group('Chỉ báo cho người dùng', () {
    testWidgets('Dải chỉ hiện trong lúc đang tải', (tester) async {
      // Giữ ảnh ở trạng thái đang tải để bắt được lúc dải hiện.
      final khoa = Completer<void>();
      final anh = IllustrationService(base: kGoc, tai: (_) => khoa.future);

      await tester.pumpWidget(
        ChangeNotifierProvider<IllustrationService>.value(
          value: anh,
          child: const MaterialApp(
            home: Scaffold(body: IllustrationProgress()),
          ),
        ),
      );

      expect(find.textContaining('Đang tải ảnh'), findsNothing);

      unawaited(anh.dongBo([makeCard(id: 'a', imagePath: 'anh/a.webp')]));
      await tester.pump();
      expect(find.text('Đang tải ảnh minh hoạ 0/1'), findsOneWidget);

      khoa.complete();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Đang tải ảnh'),
        findsNothing,
        reason: 'Tải xong thì dải phải tự biến mất',
      );
    });

    testWidgets('Cài đặt nói rõ đã tải đủ ảnh và xem được khi mất mạng', (
      tester,
    ) async {
      final anh = IllustrationService(base: kGoc, tai: (_) async {});
      await anh.dongBo([
        makeCard(id: 'a', imagePath: 'anh/a.webp'),
        makeCard(id: 'b', imagePath: 'anh/b.webp'),
      ]);

      await tester.pumpWidget(
        ChangeNotifierProvider<IllustrationService>.value(
          value: anh,
          child: const MaterialApp(
            home: Scaffold(body: IllustrationStatusLine()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã tải đủ 2 ảnh'), findsOneWidget);
    });
  });

  group('Mặt thẻ khi thiếu ảnh', () {
    Widget dungMatTruoc(Flashcard card, IllustrationService? anh) {
      final mat = MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 320, height: 420, child: CardFront(card: card)),
        ),
      );
      if (anh == null) return mat;
      return ChangeNotifierProvider<IllustrationService>.value(
        value: anh,
        child: mat,
      );
    }

    testWidgets('Thẻ KHÔNG có ảnh vẫn hiện đủ từ và phiên âm', (tester) async {
      final anh = IllustrationService(base: kGoc, tai: (_) async {});
      await tester.pumpWidget(dungMatTruoc(makeCard(id: 'a'), anh));
      await tester.pumpAndSettle();

      expect(find.text('wa'), findsOneWidget);
      expect(find.text('/w/'), findsOneWidget);
      expect(
        find.byType(Image),
        findsNothing,
        reason: 'Không có ảnh thì không được dựng widget ảnh nào',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Không có dịch vụ ảnh thì mặt thẻ vẫn dựng được', (
      tester,
    ) async {
      // Đây là điều kiện để mọi bài test cũ và mọi màn hình không quan tâm tới
      // ảnh vẫn chạy bình thường.
      await tester.pumpWidget(
        dungMatTruoc(makeCard(id: 'a', imagePath: 'anh/a.webp'), null),
      );
      await tester.pumpAndSettle();

      expect(find.text('wa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
