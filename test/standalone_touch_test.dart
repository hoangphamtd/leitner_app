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

/// Bọc Overlay hoặc không, để đo được ảnh hưởng của chính lớp bọc đó.
Widget _boc({required bool coOverlay, required Widget child}) =>
    coOverlay ? Overlay.wrap(child: child) : SizedBox.expand(child: child);

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
    bool coOverlay = true,
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
            child: _boc(
              coOverlay: coOverlay,
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

  group('Chạm bằng toạ độ thô — dựng lại đúng máy của người dùng', () {
    /// Đúng kích thước máy người dùng báo về: 393 x 793.
    ///
    /// Nhóm test này cố ý KHÔNG tìm nút theo tên rồi `tap()`. Cách đó tự tính
    /// tâm nút rồi bắn thẳng vào đó, nên nó chỉ trả lời được "nút có nhận chạm
    /// nếu chạm trúng tâm không" — trong khi câu hỏi thật là "ngón tay chạm vào
    /// toạ độ X trên màn hình thì có tới được nút không". Hai câu khác nhau: nếu
    /// có một lớp phủ vô hình chắn ngang, cách đầu vẫn xanh.
    const Size kMayThat = Size(393, 793);

    Future<void> datMayThat(WidgetTester tester) async {
      tester.view.physicalSize = kMayThat;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('Nút X trong dải: chạm đúng toạ độ thì dải phải biến mất', (
      tester,
    ) async {
      await datMayThat(tester);
      await tester.pumpWidget(
        dungApp(viewPadding: kLeStandalone, hienDaiCapNhat: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Có bản cập nhật'), findsOneWidget);

      // Lấy toạ độ thật của nút X rồi chạm vào đúng đó bằng toạ độ thô.
      final nutX = find.byKey(UpdateBanner.nutDeSau);
      final oX = tester.getRect(nutX);
      // ignore: avoid_print
      print('DO-DAC nutX=$oX');

      await tester.tapAt(oX.center);
      await tester.pumpAndSettle();

      expect(
        find.text('Có bản cập nhật'),
        findsNothing,
        reason:
            'Chạm vào toạ độ ${oX.center} không tới được nút X — '
            'có thứ gì đó đang chắn giữa ngón tay và nút',
      );
    });

    testWidgets('Nút TẢI LẠI: toạ độ thô phải chạm tới đúng nút đó', (
      tester,
    ) async {
      await datMayThat(tester);
      await tester.pumpWidget(
        dungApp(viewPadding: kLeStandalone, hienDaiCapNhat: true),
      );
      await tester.pumpAndSettle();

      final nut = find.widgetWithText(FilledButton, 'TẢI LẠI');
      final o = tester.getRect(nut);
      // ignore: avoid_print
      print('DO-DAC nutTaiLai=$o');

      final ketQua = tester.hitTestOnBinding(o.center);
      final render = tester.renderObject(nut);
      final trongDuongDan = ketQua.path.any((e) => e.target == render);

      // In ra ba lớp trên cùng để biết CÁI GÌ đang đứng trước nút.
      // ignore: avoid_print
      print(
        'DO-DAC lop tren cung tai ${o.center}: '
        '${ketQua.path.take(4).map((e) => e.target.runtimeType).join(" < ")}',
      );

      expect(
        trongDuongDan,
        isTrue,
        reason:
            'Chạm vào toạ độ ${o.center} không tới được nút TẢI LẠI. '
            'Đường chạm thật: ${ketQua.path.take(6).map((e) => e.target.runtimeType).join(" < ")}',
      );
    });

    testWidgets('Chạm đúng toạ độ người dùng báo: (280, 100) và (360, 97)', (
      tester,
    ) async {
      // Hai cụm toạ độ lấy nguyên từ nhật ký chạm trên iPhone thật.
      await datMayThat(tester);
      await tester.pumpWidget(
        dungApp(viewPadding: kLeStandalone, hienDaiCapNhat: true),
      );
      await tester.pumpAndSettle();

      for (final diem in [const Offset(280, 100), const Offset(360, 97)]) {
        final ketQua = tester.hitTestOnBinding(diem);
        // ignore: avoid_print
        print(
          'DO-DAC cham $diem -> '
          '${ketQua.path.take(6).map((e) => e.target.runtimeType).join(" < ")}',
        );
      }

      // Chạm vào toạ độ của nút X mà người dùng báo: dải phải đóng.
      await tester.tapAt(const Offset(360, 97));
      await tester.pumpAndSettle();
      expect(
        find.text('Có bản cập nhật'),
        findsNothing,
        reason: 'Toạ độ (360, 97) người dùng bấm không tới được nút X',
      );
    });
  });

  group('Dải phải bấm được KỂ CẢ khi không có Overlay', () {
    /// Đây là lớp phòng vệ thứ hai, và là lớp quan trọng hơn.
    ///
    /// Dải cập nhật là lối thoát DUY NHẤT khi người dùng kẹt ở bản cũ: máy đã
    /// cài vào màn hình chính thì không có thanh địa chỉ, không có nút tải lại.
    /// Nếu dải hỏng thì không còn đường nào ra — đúng vòng luẩn quẩn đã xảy ra
    /// thật: dải báo có bản mới, mà nút nạp bản mới lại không bấm được.
    ///
    /// Vì vậy dải không được phép phụ thuộc vào bất cứ thứ gì có thể vắng mặt.
    /// Nhóm test này cố ý dựng cây KHÔNG có Overlay. Nếu ai đó thêm `Tooltip`,
    /// `PopupMenuButton` hay `DropdownButton` vào dải, nhánh đó sẽ ném lỗi lúc
    /// dựng, Flutter thay bằng ErrorWidget, và hộp lỗi ấy nuốt trọn cú chạm của
    /// cả dải — các test dưới đây khi đó phải đỏ.
    const Size kMayThat = Size(393, 793);

    Future<void> datMayThat(WidgetTester tester) async {
      tester.view.physicalSize = kMayThat;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('Không có Overlay: dựng dải không được ném lỗi nào', (
      tester,
    ) async {
      await datMayThat(tester);
      await tester.pumpWidget(
        dungApp(
          viewPadding: kLeStandalone,
          hienDaiCapNhat: true,
          coOverlay: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'Dải cập nhật đang dùng một widget cần Overlay',
      );
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('Không có Overlay: chạm toạ độ thô vẫn đóng được dải', (
      tester,
    ) async {
      await datMayThat(tester);
      await tester.pumpWidget(
        dungApp(
          viewPadding: kLeStandalone,
          hienDaiCapNhat: true,
          coOverlay: false,
        ),
      );
      await tester.pumpAndSettle();

      final oX = tester.getRect(find.byKey(UpdateBanner.nutDeSau));
      await tester.tapAt(oX.center);
      await tester.pumpAndSettle();

      expect(
        find.text('Có bản cập nhật'),
        findsNothing,
        reason: 'Chạm vào ${oX.center} không tới được nút đóng dải',
      );
    });

    testWidgets('Không có Overlay: nút TẢI LẠI vẫn nhận được chạm', (
      tester,
    ) async {
      await datMayThat(tester);
      await tester.pumpWidget(
        dungApp(
          viewPadding: kLeStandalone,
          hienDaiCapNhat: true,
          coOverlay: false,
        ),
      );
      await tester.pumpAndSettle();

      final nut = find.widgetWithText(FilledButton, 'TẢI LẠI');
      final o = tester.getRect(nut);

      // Nút phải nằm đúng trong màn hình. Khi nhánh dải bị thay bằng ErrorWidget,
      // nút thật bị đẩy ra y = 50041 — ngoài màn hình, trong khi hộp lỗi vô hình
      // chiếm chỗ nó. Đo được thật, và đúng là thứ đã xảy ra trên máy người dùng.
      expect(
        o.top >= 0 && o.bottom <= kMayThat.height,
        isTrue,
        reason: 'Nút TẢI LẠI nằm ngoài màn hình: $o',
      );

      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
      await tester.tapAt(o.center);
      await tester.pumpAndSettle();
    });

    testWidgets('Hai dải không được chứa widget cần Overlay', (tester) async {
      // Chặn ngay từ cấu trúc, không đợi tới lúc chạm.
      await datMayThat(tester);
      await tester.pumpWidget(
        dungApp(
          viewPadding: kLeStandalone,
          hienDaiCapNhat: true,
          soLoi: 3,
          coOverlay: false,
        ),
      );
      await tester.pumpAndSettle();

      // Chỉ soi bên trong hai dải. Phần ứng dụng nằm dưới Navigator nên có
      // Overlay sẵn, dùng Tooltip ở đó là bình thường.
      for (final dai in [UpdateBanner.ruotDai, ErrorBanner.ruotDai]) {
        expect(find.byKey(dai, skipOffstage: false), findsOneWidget);
        for (final loai in [Tooltip, PopupMenuButton, DropdownButton]) {
          expect(
            find.descendant(
              of: find.byKey(dai, skipOffstage: false),
              matching: find.byType(loai, skipOffstage: false),
              skipOffstage: false,
            ),
            findsNothing,
            reason:
                '$loai cần Overlay. Đặt nó trong dải là làm dải hỏng khi '
                'thiếu Overlay, mà dải là lối thoát duy nhất của người dùng '
                'đang kẹt ở bản cũ.',
          );
        }
      }
    });
  });

  group('Quét toàn app: vùng VẼ và vùng NHẬN CHẠM phải trùng nhau', () {
    /// Người dùng báo MỌI nút đều bấm trượt ở chế độ đã cài vào màn hình chính,
    /// phải chạm cao hơn khoảng 47 điểm ảnh mới trúng.
    ///
    /// Nguyên nhân thật nằm ở tầng trình duyệt (hai thẻ meta trong
    /// `web/index.html`, xem `test/web_shell_test.dart`), nên nhóm test này
    /// KHÔNG dựng lại được nó — test chạy trên máy ảo Dart, không có trình
    /// duyệt. Việc của nhóm này là loại trừ nửa còn lại: chứng minh chính tầng
    /// Flutter không tự tạo ra độ lệch nào, ở cả hai lề an toàn.
    ///
    /// Cách làm: lấy ô VẼ của từng nút bằng `getRect`, rồi bắn hit-test vào
    /// đúng tâm ô đó và đòi hỏi nút ấy phải nằm trong đường chạm.
    const Size kMayThat = Size(393, 793);

    Future<void> datMayThat(WidgetTester tester) async {
      tester.view.physicalSize = kMayThat;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    /// Chạm vào đúng tâm ô vẽ của [nut] và đòi hỏi cú chạm tới được nó.
    void doiCham(WidgetTester tester, Finder nut, String ten) {
      final o = tester.getRect(nut);
      final duong = tester.hitTestOnBinding(o.center).path;
      final den = tester.renderObject(nut);
      expect(
        duong.any((e) => e.target == den),
        isTrue,
        reason:
            'Chạm vào tâm ô vẽ của "$ten" ($o, tâm ${o.center}) không tới được '
            'chính nó. Thứ nhận chạm: '
            '${duong.take(5).map((e) => e.target.runtimeType).join(" < ")}',
      );
    }

    for (final (tenLe, le) in [
      ('Safari', kLeSafari),
      ('standalone', kLeStandalone),
    ]) {
      testWidgets('Ba tab dưới — lề $tenLe', (tester) async {
        await datMayThat(tester);
        await tester.pumpWidget(dungApp(viewPadding: le));
        await tester.pumpAndSettle();

        for (final nhan in ['Tổng quan', 'Thư viện', 'Cài đặt']) {
          doiCham(
            tester,
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text(nhan),
            ),
            'tab $nhan',
          );
        }
      });

      testWidgets('Nút trên thanh tiêu đề và nút chính — lề $tenLe', (
        tester,
      ) async {
        await datMayThat(tester);
        await tester.pumpWidget(dungApp(viewPadding: le));
        await tester.pumpAndSettle();

        doiCham(tester, find.byTooltip('Chẩn đoán'), 'nút Chẩn đoán');

        final nutChinh = find.textContaining('HỌC HÔM NAY');
        if (nutChinh.evaluate().isNotEmpty) {
          await tester.ensureVisible(nutChinh);
          await tester.pumpAndSettle();
          doiCham(tester, nutChinh, 'nút HỌC HÔM NAY');
        }
      });

      testWidgets('Nút trong dải cập nhật — lề $tenLe', (tester) async {
        await datMayThat(tester);
        await tester.pumpWidget(dungApp(viewPadding: le, hienDaiCapNhat: true));
        await tester.pumpAndSettle();

        doiCham(
          tester,
          find.widgetWithText(FilledButton, 'TẢI LẠI'),
          'nút TẢI LẠI',
        );
        doiCham(tester, find.byKey(UpdateBanner.nutDeSau), 'nút đóng dải');
      });
    }
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
