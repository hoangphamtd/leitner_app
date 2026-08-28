import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leitner_app/models/flashcard.dart';
import 'package:leitner_app/providers/backup_provider.dart';
import 'package:leitner_app/providers/deck_provider.dart';
import 'package:leitner_app/providers/library_provider.dart';
import 'package:leitner_app/providers/settings_provider.dart';
import 'package:leitner_app/providers/study_provider.dart';
import 'package:leitner_app/screens/home_screen.dart';
import 'package:leitner_app/screens/library_screen.dart';
import 'package:leitner_app/services/leitner_service.dart';
import 'package:leitner_app/widgets/box_tile.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_pronunciation.dart';
import 'fakes/fake_repositories.dart';

/// Kiểm tra bố cục ở đúng kích thước iPhone thường.
///
/// Lý do có nhóm test này: ba lỗi tràn chữ đã lọt ra tới máy người dùng thật vì
/// mọi lần thử trước đều chạy trên cửa sổ máy tính rộng rãi. Màn hình iPhone
/// thường chỉ rộng 390 điểm ảnh — chia cho năm ô hộp thì mỗi ô còn khoảng 66,
/// đủ chật để chữ xuống dòng rồi đè lên nhau.
///
/// Điểm mạnh của cách kiểm tra này: Flutter tự ném lỗi khi có widget tràn khỏi
/// khung, nên test bắt được cả những chỗ mắt thường nhìn ảnh chụp dễ bỏ qua.
const Size kIPhone = Size(390, 844);

Flashcard makeCard({
  required String id,
  String word = 'word',
  int boxNumber = 1,
  bool isActive = true,
}) {
  final epoch = DateTime(2025, 1, 1);
  return Flashcard(
    id: id,
    word: word,
    phonetic: '/w/',
    meaning: 'nghĩa tiếng Việt khá dài để thử tràn chữ',
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
  late FakeStudyLogRepository logs;
  late FakeSettingsRepository settings;
  late FakeSessionStateRepository sessions;

  setUp(() {
    cards = FakeCardRepository();
    logs = FakeStudyLogRepository();
    settings = FakeSettingsRepository();
    sessions = FakeSessionStateRepository();
  });

  /// Đặt màn hình đúng cỡ iPhone thường cho cả bài test.
  Future<void> datManHinhIPhone(WidgetTester tester) async {
    tester.view.physicalSize = kIPhone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget dungCay(Widget child) {
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
          create: (_) => SettingsProvider(
            repository: settings,
            pronunciation: FakePronunciation(),
          ),
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
      child: MaterialApp(home: child),
    );
  }

  group('Màn hình Tổng quan trên iPhone 390 x 844', () {
    testWidgets('Năm ô hộp không tràn chữ', (tester) async {
      await datManHinhIPhone(tester);
      // Hộp 1 có số hai chữ số và đang được làm nổi bật — đúng tình huống bị
      // tràn trong ảnh chụp của người dùng.
      cards.seed([
        for (var i = 0; i < 15; i++) makeCard(id: 'a$i'),
        makeCard(id: 'b1', boxNumber: 2),
        makeCard(id: 'c1', boxNumber: 4),
      ]);

      await tester.pumpWidget(dungCay(const HomeScreen()));
      await tester.pumpAndSettle();

      // pumpAndSettle sẽ ném lỗi nếu có widget tràn khung, nên tới được đây
      // nghĩa là bố cục vừa vặn.
      expect(find.byType(BoxTile), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Nhãn lịch của mọi hộp đều gọn trong một dòng', (tester) async {
      await datManHinhIPhone(tester);
      await tester.pumpWidget(dungCay(const HomeScreen()));
      await tester.pumpAndSettle();

      for (final nhan in BoxTile.scheduleLabels.values) {
        final widget = tester.widget<Text>(find.text(nhan));
        expect(
          widget.maxLines,
          1,
          reason: 'Nhãn "$nhan" phải gói trong một dòng, '
              'nếu không sẽ đè lên chữ khác như đã xảy ra',
        );
      }
    });

    testWidgets('Nhãn lịch đủ ngắn để không phải thu nhỏ quá đà', (tester) async {
      // Chặn ngay từ dữ liệu: nhãn dài thì dù có FittedBox cũng bị thu nhỏ tới
      // mức không đọc nổi trên màn hình điện thoại.
      for (final nhan in BoxTile.scheduleLabels.values) {
        expect(
          nhan.length,
          lessThanOrEqualTo(10),
          reason: 'Nhãn "$nhan" quá dài cho ô rộng khoảng 66 điểm ảnh',
        );
      }
    });

    testWidgets('Nút HỌC HÔM NAY vẫn nằm trong màn hình đầu', (tester) async {
      // Lưới ô hộp cao quá sẽ đẩy nút chính xuống dưới vùng nhìn thấy, người
      // học phải cuộn mới bấm được — hỏng mất mục đích của nút.
      await datManHinhIPhone(tester);
      cards.seed([for (var i = 0; i < 15; i++) makeCard(id: 'a$i')]);

      await tester.pumpWidget(dungCay(const HomeScreen()));
      await tester.pumpAndSettle();

      final nut = find.textContaining('HỌC HÔM NAY');
      expect(nut, findsOneWidget);
      final oNut = tester.getRect(nut);
      expect(
        oNut.bottom,
        lessThan(kIPhone.height),
        reason: 'Nút chính phải thấy được ngay, không phải cuộn',
      );
    });
  });

  group('Màn hình Thư viện trên iPhone 390 x 844', () {
    testWidgets('Cuộn tới cuối vẫn đọc được dòng cuối cùng', (tester) async {
      // Nút nổi THÊM TỪ từng che mất dòng cuối, người dùng không cuộn tới được.
      await datManHinhIPhone(tester);
      cards.seed([
        for (var i = 0; i < 15; i++)
          makeCard(id: 'w$i', word: 'word${i.toString().padLeft(2, '0')}'),
      ]);

      await tester.pumpWidget(dungCay(const LibraryScreen()));
      await tester.pumpAndSettle();

      // Cuộn xuống hết cỡ.
      await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000);
      await tester.pumpAndSettle();

      final dongCuoi = find.text('word14');
      expect(dongCuoi, findsOneWidget);

      final oDongCuoi = tester.getRect(dongCuoi);
      final oNutThemTu = tester.getRect(find.text('THÊM TỪ'));

      expect(
        oDongCuoi.bottom,
        lessThanOrEqualTo(oNutThemTu.top),
        reason: 'Dòng cuối phải nằm hẳn trên nút THÊM TỪ, không bị che',
      );
    });

    testWidgets('Danh sách không tràn khung', (tester) async {
      await datManHinhIPhone(tester);
      cards.seed([for (var i = 0; i < 20; i++) makeCard(id: 'w$i')]);

      await tester.pumpWidget(dungCay(const LibraryScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
