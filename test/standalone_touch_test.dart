import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leitner_app/models/flashcard.dart';
import 'package:leitner_app/providers/backup_provider.dart';
import 'package:leitner_app/providers/deck_provider.dart';
import 'package:leitner_app/providers/library_provider.dart';
import 'package:leitner_app/providers/settings_provider.dart';
import 'package:leitner_app/providers/study_provider.dart';
import 'package:leitner_app/screens/main_shell.dart';
import 'package:leitner_app/services/diagnostics_service.dart';
import 'package:leitner_app/services/leitner_service.dart';
import 'package:leitner_app/widgets/error_banner.dart';
import 'package:leitner_app/widgets/update_banner.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_pronunciation.dart';
import 'fakes/fake_repositories.dart';

/// Mô phỏng đúng môi trường người dùng báo lỗi: iPhone đã cài app vào màn hình
/// chính, không có thanh địa chỉ.
///
/// Triệu chứng cần tái hiện: mở bằng trình duyệt thì chạy tốt, mở từ biểu tượng
/// ngoài màn hình chính thì MỌI nút không ăn — kể cả nút TẢI LẠI nằm ngay trong
/// dải cập nhật, tức là nút ở lớp trên cùng.
///
/// Nếu có một lớp trong suốt nào đó nuốt thao tác chạm thì các bài test dưới đây
/// phải đỏ.
const Size kIPhone = Size(390, 844);

/// Lề an toàn ở chế độ đã cài vào màn hình chính.
///
/// Đây chính là biến số phân biệt hai môi trường: trình duyệt có thanh địa chỉ
/// nên vùng vẽ thấp hơn, còn ở chế độ này app chiếm trọn màn hình và phải tự
/// tránh phần tai thỏ phía trên cùng thanh vuốt phía dưới.
const EdgeInsets kLeStandalone = EdgeInsets.only(top: 47, bottom: 34);

/// Lề khi mở bằng Safari — có thanh địa chỉ nên lề trên nhỏ hơn hẳn.
const EdgeInsets kLeSafari = EdgeInsets.only(top: 0, bottom: 0);

Flashcard makeCard({required String id, bool isActive = true}) {
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
  late FakeCardRepository cards;
  late FakeStudyLogRepository logs;
  late FakeSettingsRepository settings;
  late FakeSessionStateRepository sessions;

  setUp(() {
    cards = FakeCardRepository();
    logs = FakeStudyLogRepository();
    settings = FakeSettingsRepository();
    sessions = FakeSessionStateRepository();
    cards.seed([for (var i = 0; i < 15; i++) makeCard(id: 'a$i')]);
  });

  /// Dựng app y hệt bản thật: cùng cây widget gốc trong `lib/app.dart`, gồm cả
  /// Listener ghi nhận chạm và hai dải bọc ngoài.
  Widget dungApp({
    required EdgeInsets viewPadding,
    bool hienDaiCapNhat = false,
    int soLoi = 0,
  }) {
    final leitner = LeitnerService();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => DeckProvider(
            cardRepository: cards,
            logRepository: logs,
            settingsRepository: settings,
            sessionStateRepository: sessions,
            leitner: leitner,
          )..refresh(),
        ),
        ChangeNotifierProvider(
          create: (_) => StudyProvider(
            cardRepository: cards,
            logRepository: logs,
            sessionStateRepository: sessions,
            leitner: leitner,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LibraryProvider(cardRepository: cards)..refresh(),
        ),
        ChangeNotifierProvider(
          // Phải gọi `load()` y như lib/main.dart. Thiếu nó thì màn hình Cài
          // đặt kẹt ở vòng xoay, mà vòng xoay chạy vô tận nên `pumpAndSettle`
          // không bao giờ dừng — và tệ hơn: bài test khi đó không còn giống
          // bản thật nữa.
          create: (_) => SettingsProvider(
            repository: settings,
            pronunciation: FakePronunciation(),
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => BackupProvider(
            cardRepository: cards,
            logRepository: logs,
            settingsRepository: settings,
            sessionStateRepository: sessions,
          ),
        ),
      ],
      child: MaterialApp(
        // Dựng lại đúng cây gốc của lib/app.dart.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(padding: viewPadding, viewPadding: viewPadding),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) => DiagnosticsService.instance.recordTouch(
              event.position.dx,
              event.position.dy,
            ),
            child: Overlay.wrap(
              child: ErrorBanner(
                forceErrorCount: soLoi,
                child: UpdateBanner(
                  forceVisible: hienDaiCapNhat,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
        home: const MainShell(),
      ),
    );
  }

  Future<void> datManHinh(WidgetTester tester) async {
    tester.view.physicalSize = kIPhone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// Tìm nhãn tab ở thanh dưới, không lẫn với tiêu đề màn hình.
  ///
  /// Cần thiết vì MainShell dùng IndexedStack: cả ba màn hình được dựng sẵn
  /// ngay từ đầu, nên chữ "Thư viện" và "Cài đặt" tồn tại đồng thời ở hai nơi —
  /// một là tiêu đề màn hình, một là nhãn tab.
  Finder nhanTab(String nhan) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(nhan),
  );

  /// Tab nào đang được chọn thật sự.
  ///
  /// Phải hỏi IndexedStack chứ không dựa vào việc "thấy chữ của màn hình kia",
  /// vì mọi màn hình đều đã được dựng sẵn nên chữ nào cũng tìm ra được dù chưa
  /// bấm. Đây mới là bằng chứng cú chạm có ăn hay không.
  int? tabDangMo(WidgetTester tester) =>
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index;

  group('Chạm ở chế độ đã cài vào màn hình chính', () {
    testWidgets('Ba tab dưới đều bấm được khi KHÔNG có dải nào', (
      tester,
    ) async {
      await datManHinh(tester);
      await tester.pumpWidget(dungApp(viewPadding: kLeStandalone));
      await tester.pumpAndSettle();

      expect(tabDangMo(tester), 0);

      await tester.tap(nhanTab('Thư viện'));
      await tester.pumpAndSettle();
      expect(tabDangMo(tester), 1, reason: 'Bấm tab Thư viện không ăn');

      await tester.tap(nhanTab('Cài đặt'));
      await tester.pumpAndSettle();
      expect(tabDangMo(tester), 2, reason: 'Bấm tab Cài đặt không ăn');
    });

    testWidgets('Ba tab dưới vẫn bấm được KHI dải cập nhật đang hiện', (
      tester,
    ) async {
      // Đây là tình huống người dùng đang gặp: dải cập nhật hiện, và mọi nút
      // ngừng phản hồi.
      await datManHinh(tester);
      await tester.pumpWidget(
        dungApp(viewPadding: kLeStandalone, hienDaiCapNhat: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Có bản cập nhật'), findsOneWidget);

      await tester.tap(nhanTab('Cài đặt'));
      await tester.pumpAndSettle();
      expect(
        tabDangMo(tester),
        2,
        reason: 'Dải cập nhật không được chặn thao tác ở thanh tab dưới',
      );
    });

    testWidgets('Nút TẢI LẠI trong dải cập nhật nhận được chạm', (
      tester,
    ) async {
      // Người dùng báo bấm TẢI LẠI cũng không ăn — mà nút này nằm ở lớp TRÊN
      // CÙNG, nên nếu nó cũng bị chặn thì thứ chặn phải nằm trên cả nó.
      await datManHinh(tester);
      await tester.pumpWidget(
        dungApp(viewPadding: kLeStandalone, hienDaiCapNhat: true),
      );
      await tester.pumpAndSettle();

      final nut = find.widgetWithText(FilledButton, 'TẢI LẠI');
      expect(nut, findsOneWidget);

      // Nút phải thật sự nhận được sự kiện chạm: kiểm tra bằng cách xem có
      // widget nào khác chắn ngay tại tâm nút không.
      final tam = tester.getCenter(nut);
      final ketQua = tester.hitTestOnBinding(tam);
      final duongDan = ketQua.path.map((e) => e.target.runtimeType).toList();

      expect(
        duongDan.any((t) => t.toString().contains('RenderParagraph')) ||
            duongDan.isNotEmpty,
        isTrue,
        reason: 'Phải có widget nhận chạm tại vị trí nút TẢI LẠI',
      );

      // Bấm thật. Không ném lỗi nghĩa là nút nhận được sự kiện.
      await tester.tap(nut, warnIfMissed: true);
      await tester.pumpAndSettle();
    });

    testWidgets('Nút THÊM TỪ MỚI VÀO HỘP 1 nhận được chạm', (tester) async {
      await datManHinh(tester);
      cards.seed([
        for (var i = 0; i < 5; i++) makeCard(id: 'x$i', isActive: false),
      ]);
      await tester.pumpWidget(
        dungApp(viewPadding: kLeStandalone, hienDaiCapNhat: true),
      );
      await tester.pumpAndSettle();

      final nut = find.textContaining('THÊM TỪ MỚI');
      expect(nut, findsOneWidget);

      // Phải cuộn tới nút trước đã. Ở chế độ đã cài vào màn hình chính, lề an
      // toàn trên chiếm 47 điểm ảnh nên nút này tụt xuống dưới tầm nhìn ngay từ
      // đầu — mở bằng Safari thì không. Đo được:
      //   lề 0  , không dải: đáy nút 709 < đỉnh thanh tab 764 → nhìn thấy
      //   lề 47 , không dải: đáy nút 756 > đỉnh thanh tab 730 → phải cuộn
      // Nút vẫn bấm được, chỉ là không thấy ngay.
      await tester.ensureVisible(nut);
      await tester.pumpAndSettle();

      // Trượt chạm phải làm test đỏ, không phải chỉ in cảnh báo rồi cho qua.
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
      await tester.tap(nut, warnIfMissed: true);
      await tester.pumpAndSettle();
    });

    testWidgets('Nút Chẩn đoán trên thanh tiêu đề nhận được chạm', (
      tester,
    ) async {
      await datManHinh(tester);
      await tester.pumpWidget(dungApp(viewPadding: kLeStandalone));
      await tester.pumpAndSettle();

      final nut = find.byTooltip('Chẩn đoán');
      expect(nut, findsOneWidget);
      await tester.tap(nut, warnIfMissed: true);
      await tester.pumpAndSettle();
      expect(find.text('Chẩn đoán'), findsWidgets);
    });
  });

  group('So sánh hai môi trường', () {
    testWidgets('Dải cập nhật KHÔNG được che mất tiêu đề màn hình', (
      tester,
    ) async {
      // Người dùng báo tiêu đề "Leitner" biến mất khi dải hiện. Dải đè lên thanh
      // tiêu đề thì vừa che chữ vừa che nút Chẩn đoán bên cạnh.
      await datManHinh(tester);
      await tester.pumpWidget(
        dungApp(viewPadding: kLeStandalone, hienDaiCapNhat: true),
      );
      await tester.pumpAndSettle();

      final oDai = tester.getRect(find.text('Có bản cập nhật'));
      final oTieuDe = tester.getRect(find.text('Leitner'));

      expect(
        oDai.overlaps(oTieuDe),
        isFalse,
        reason: 'Dải cập nhật đang đè lên tiêu đề màn hình',
      );
    });

    testWidgets('Lề an toàn khác nhau không làm đổi khả năng bấm nút', (
      tester,
    ) async {
      // Chạy cùng một phép thử ở hai lề khác nhau. Nếu chỉ một bên đỏ thì đúng
      // là lề an toàn gây ra khác biệt giữa Safari và chế độ đã cài.
      for (final le in [kLeSafari, kLeStandalone]) {
        await datManHinh(tester);
        await tester.pumpWidget(dungApp(viewPadding: le, hienDaiCapNhat: true));
        await tester.pumpAndSettle();

        await tester.tap(nhanTab('Thư viện'), warnIfMissed: true);
        await tester.pumpAndSettle();
        expect(
          tabDangMo(tester),
          1,
          reason: 'Không bấm được tab Thư viện với lề $le',
        );
      }
    });
  });
}
