import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leitner_app/models/flashcard.dart';
import 'package:leitner_app/providers/settings_provider.dart';
import 'package:leitner_app/providers/study_provider.dart';
import 'package:leitner_app/screens/study_screen.dart';
import 'package:leitner_app/services/leitner_service.dart';
import 'package:leitner_app/widgets/card_faces.dart';
import 'package:leitner_app/widgets/flip_card.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_pronunciation.dart';
import 'fakes/fake_repositories.dart';

/// Bản đồ vùng bấm được của màn hình Học, đo trên đúng máy người dùng báo.
///
/// Đây là công cụ đo, không phải bài kiểm tra: nó quét từng điểm trên màn hình
/// rồi in ra chỗ nào chạm ăn, chỗ nào chạm trượt.
const Size kMayThat = Size(393, 793);
const EdgeInsets kLeStandalone = EdgeInsets.only(top: 47, bottom: 34);

Flashcard theMau({String? anh}) => Flashcard(
  id: 'a',
  word: 'apple',
  phonetic: '/ˈæpəl/',
  meaning: 'quả táo',
  exampleSentence: 'I eat an apple every day.',
  boxNumber: 1,
  nextReviewDate: DateTime(2025, 1, 1),
  imagePath: anh,
  isActive: true,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
);

void main() {
  testWidgets('BẢN ĐỒ vùng bấm được của màn hình Học', (tester) async {
    final cards = FakeCardRepository();
    final logs = FakeStudyLogRepository();
    final settings = FakeSettingsRepository();
    final sessions = FakeSessionStateRepository();

    tester.view.physicalSize = kMayThat;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final study = StudyProvider(
      cardRepository: cards,
      logRepository: logs,
      sessionStateRepository: sessions,
      leitner: LeitnerService(),
    );
    await study.start([theMau()]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<StudyProvider>.value(value: study),
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(
              repository: settings,
              pronunciation: FakePronunciation(),
            )..load(),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(padding: kLeStandalone, viewPadding: kLeStandalone),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const StudyScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final loiBoCuc = tester.takeException();
    debugPrint('BANDO  Lỗi bố cục khi dựng: ${loiBoCuc ?? "không có"}');

    void inO(String ten, Finder f) {
      if (f.evaluate().isEmpty) {
        debugPrint('BANDO  $ten: KHÔNG CÓ');
        return;
      }
      debugPrint('BANDO  $ten: ${tester.getRect(f.first)}');
    }

    debugPrint('=== Ô CỦA TỪNG PHẦN ===');
    inO('Toàn thẻ (FlipCard)', find.byType(FlipCard));
    inO('Chữ "apple"', find.text('apple'));
    inO('Phiên âm', find.text('/ˈæpəl/'));
    inO('Nút loa', find.byType(SpeakerButton));
    inO('Dòng gợi ý', find.text('Chạm vào thẻ để xem nghĩa'));

    // RenderObject của GestureDetector lật thẻ. Vì nó dùng hành vi mặc định
    // `deferToChild`, nó CHỈ có mặt trong đường chạm khi có một widget con thật
    // sự nhận được cú chạm đó. Nên "có trong đường chạm" đúng bằng "chạm ăn".
    final timNutLat = find.descendant(
      of: find.byType(FlipCard),
      matching: find.byType(GestureDetector),
    );
    debugPrint(
      'BANDO  Số GestureDetector trong FlipCard: '
      '${timNutLat.evaluate().length}',
    );
    final nutLat = tester.renderObject(timNutLat.first);

    final oThe = tester.getRect(find.byType(FlipCard));

    debugPrint('=== QUÉT TỪNG ĐIỂM TRONG THẺ (mỗi ô 20 điểm ảnh) ===');
    debugPrint('  .  = chạm TRƯỢT (không lật thẻ)');
    debugPrint('  #  = chạm ĂN (lật được thẻ)');
    var soAn = 0;
    var soTruot = 0;
    for (var y = oThe.top + 10; y < oThe.bottom; y += 20) {
      final buffer = StringBuffer('  y=${y.round().toString().padLeft(3)} ');
      for (var x = oThe.left + 10; x < oThe.right; x += 20) {
        final duong = tester.hitTestOnBinding(Offset(x, y)).path;
        final an = duong.any((e) => e.target == nutLat);
        buffer.write(an ? '#' : '.');
        if (an) {
          soAn++;
        } else {
          soTruot++;
        }
      }
      debugPrint(buffer.toString());
    }
    debugPrint('BANDO  Tổng: $soAn điểm ăn, $soTruot điểm trượt');

    debugPrint('=== DÒNG GỢI Ý "Chạm vào thẻ để xem nghĩa" ===');
    final oGoiY = tester.getRect(find.text('Chạm vào thẻ để xem nghĩa'));
    final duongGoiY = tester.hitTestOnBinding(oGoiY.center).path;
    debugPrint(
      'BANDO  Chạm vào giữa dòng gợi ý ${oGoiY.center} nhận được: '
      '${duongGoiY.take(6).map((e) => e.target.runtimeType).join(" < ")}',
    );
    debugPrint(
      'BANDO  Dòng gợi ý có lật được thẻ không: '
      '${duongGoiY.any((e) => e.target == nutLat)}',
    );

    debugPrint('=== MẶT SAU: vùng chạm có bị soi gương không? ===');
    // Bẫy kinh điển: mặt sau được quay bù nửa vòng, nếu phép quay đó không được
    // nghịch đảo đúng khi thử chạm thì chạm bên trái sẽ trúng bên phải.
    study.reveal();
    await tester.pumpAndSettle();
    tester.takeException();

    final oLoaSau = tester.getRect(find.byType(SpeakerButton));
    final loaSau = tester.renderObject(find.byType(SpeakerButton));
    final duongLoa = tester.hitTestOnBinding(oLoaSau.center).path;
    debugPrint('BANDO  Nút loa mặt sau vẽ ở: $oLoaSau');
    debugPrint(
      'BANDO  Chạm đúng tâm nút loa có trúng nó không: '
      '${duongLoa.any((e) => e.target == loaSau)}',
    );
    // Điểm đối xứng qua trục dọc của thẻ. Nếu vùng chạm bị soi gương thì chính
    // điểm này mới trúng nút loa, chứ không phải tâm nút.
    final oTheSau = tester.getRect(find.byType(FlipCard));
    final diemGuong = Offset(
      oTheSau.left + oTheSau.right - oLoaSau.center.dx,
      oLoaSau.center.dy,
    );
    debugPrint(
      'BANDO  Chạm ở điểm đối xứng $diemGuong có trúng nút loa không: '
      '${tester.hitTestOnBinding(diemGuong).path.any((e) => e.target == loaSau)}'
      '  (phép thử này VÔ NGHĨA vì nút loa nằm đúng tâm thẻ nên điểm đối xứng '
      'trùng luôn với tâm nút — xem ma trận bên dưới mới là bằng chứng thật)',
    );

    // Bằng chứng thật cho chuyện soi gương: lấy ma trận biến hình từ nút loa
    // lên hệ toạ độ màn hình. Hệ số [0][0] âm nghĩa là trục X bị lật.
    final ma = (loaSau as RenderBox).getTransformTo(null);
    debugPrint(
      'BANDO  Hệ số trục X của mặt sau: ${ma.entry(0, 0).toStringAsFixed(3)} '
      '(âm = bị soi gương), trục Y: ${ma.entry(1, 1).toStringAsFixed(3)}',
    );
    final goc = tester.getRect(find.text('quả táo'));
    debugPrint('BANDO  Chữ nghĩa "quả táo" vẽ ở: $goc');
    debugPrint(
      'BANDO  Chạm mép TRÁI chữ nghĩa (${goc.left + 5}, ${goc.center.dy}) '
      'nhận được: '
      '${tester.hitTestOnBinding(Offset(goc.left + 5, goc.center.dy)).path.take(3).map((e) => e.target.runtimeType).join(" < ")}',
    );

    final nutLatSau = tester.renderObject(
      find
          .descendant(
            of: find.byType(FlipCard),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    var anSau = 0;
    var truotSau = 0;
    for (var y = oTheSau.top + 10; y < oTheSau.bottom; y += 20) {
      for (var x = oTheSau.left + 10; x < oTheSau.right; x += 20) {
        if (tester
            .hitTestOnBinding(Offset(x, y))
            .path
            .any((e) => e.target == nutLatSau)) {
          anSau++;
        } else {
          truotSau++;
        }
      }
    }
    debugPrint('BANDO  Mặt sau: $anSau điểm ăn, $truotSau điểm trượt');

    debugPrint('=== ĐANG LẬT NỬA CHỪNG ===');
    // Lật ngược về mặt trước rồi lật lại, dừng ở từng nấc để đo.
    study.reveal();
    await tester.pumpAndSettle();
    tester.takeException();

    final study3 = StudyProvider(
      cardRepository: cards,
      logRepository: logs,
      sessionStateRepository: sessions,
      leitner: LeitnerService(),
    );
    await study3.start([theMau()]);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<StudyProvider>.value(value: study3),
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(
              repository: settings,
              pronunciation: FakePronunciation(),
            )..load(),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(padding: kLeStandalone, viewPadding: kLeStandalone),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const StudyScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.takeException();

    study3.reveal();
    await tester.pump();
    final nutLat3 = tester.renderObject(
      find
          .descendant(
            of: find.byType(FlipCard),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    final oThe3 = tester.getRect(find.byType(FlipCard));
    for (final moc in [40, 60, 60, 40, 60, 60, 60]) {
      await tester.pump(Duration(milliseconds: moc));
      tester.takeException();
      var an = 0;
      var tong = 0;
      for (var y = oThe3.top + 10; y < oThe3.bottom; y += 40) {
        for (var x = oThe3.left + 10; x < oThe3.right; x += 40) {
          tong++;
          if (tester
              .hitTestOnBinding(Offset(x, y))
              .path
              .any((e) => e.target == nutLat3)) {
            an++;
          }
        }
      }
      final oHienTai = tester.getRect(find.byType(FlipCard));
      debugPrint(
        'BANDO  sau ${moc}ms: $an/$tong điểm ăn · ô thẻ vẫn $oHienTai',
      );
    }

    debugPrint('=== SO SÁNH: thẻ CÓ ảnh ===');
    final study2 = StudyProvider(
      cardRepository: cards,
      logRepository: logs,
      sessionStateRepository: sessions,
      leitner: LeitnerService(),
    );
    await study2.start([theMau(anh: 'khong-co-that.png')]);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<StudyProvider>.value(value: study2),
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(
              repository: settings,
              pronunciation: FakePronunciation(),
            )..load(),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(padding: kLeStandalone, viewPadding: kLeStandalone),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const StudyScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.takeException();
    final nutLat2 = tester.renderObject(
      find
          .descendant(
            of: find.byType(FlipCard),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    final oThe2 = tester.getRect(find.byType(FlipCard));
    var an2 = 0;
    var truot2 = 0;
    for (var y = oThe2.top + 10; y < oThe2.bottom; y += 20) {
      for (var x = oThe2.left + 10; x < oThe2.right; x += 20) {
        if (tester
            .hitTestOnBinding(Offset(x, y))
            .path
            .any((e) => e.target == nutLat2)) {
          an2++;
        } else {
          truot2++;
        }
      }
    }
    debugPrint('BANDO  Thẻ có ảnh: $an2 điểm ăn, $truot2 điểm trượt');
  });
}
