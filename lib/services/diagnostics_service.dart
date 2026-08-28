import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../utils/web_metrics/web_metrics.dart';

/// Một lần chạm và độ trễ tới khung hình vẽ ngay sau đó.
class TouchSample {
  /// Mili-giây kể từ lúc app khởi động, để biết chạm lúc nào.
  final int atMs;

  /// Mili-giây từ lúc ngón tay chạm xuống tới lúc khung hình kế tiếp vẽ xong.
  ///
  /// Đây chính là con số người dùng cảm nhận là "nút có ăn hay không". Dưới 100
  /// là mượt, trên 300 là thấy khựng, trên 1000 là tưởng hỏng.
  final int latencyMs;

  /// Toạ độ chạm THEO FLUTTER, tức nơi Flutter tin là ngón tay vừa chạm.
  final int x;
  final int y;

  /// Toạ độ chạm THEO TRÌNH DUYỆT cho cùng cú chạm đó. Null nếu không đo được.
  ///
  /// Hai bộ toạ độ này phải trùng nhau. Lệch nhau nghĩa là vùng vẽ và vùng nhận
  /// chạm không cùng một hệ toạ độ — người dùng bấm trúng chỗ nhìn thấy nút mà
  /// vẫn trượt, đúng bằng độ lệch. Không bài test widget nào bắt được chuyện
  /// này vì nó xảy ra ở tầng trình duyệt, nên phải đo thẳng trên máy thật.
  final int? thoX;
  final int? thoY;

  /// Tên các lớp vẽ trên cùng của đường chạm, tức thứ THẬT SỰ nhận cú chạm.
  ///
  /// Toạ độ đúng không có nghĩa là chạm trúng nút. Danh sách này cho biết ngay
  /// cú chạm rơi vào đâu, khỏi phải đoán.
  final List<String> nhanBoi;

  /// Độ lệch dọc giữa hai hệ toạ độ. Null nếu không đo được.
  int? get lechDoc => thoY == null ? null : y - thoY!;

  const TouchSample({
    required this.atMs,
    required this.latencyMs,
    required this.x,
    required this.y,
    this.thoX,
    this.thoY,
    this.nhanBoi = const [],
  });
}

/// Một lỗi bắt được ở tầng Dart.
class DartErrorSample {
  final int atMs;
  final String message;

  const DartErrorSample({required this.atMs, required this.message});
}

/// Thu thập số liệu hiệu năng ngay trên máy người dùng.
///
/// Lý do tồn tại: lỗi chậm chỉ xuất hiện trên điện thoại thật, mà trên điện
/// thoại thì không mở được công cụ nhà phát triển. Thay vì đoán, app tự đo rồi
/// hiện số lên màn hình.
///
/// Lớp này cố ý rất nhẹ: chỉ ghi con số, không tính toán gì trong lúc đo, để
/// bản thân việc đo không làm chậm thêm thứ đang cần đo.
class DiagnosticsService extends ChangeNotifier {
  DiagnosticsService._();

  /// Dùng chung một thể hiện cho toàn app, vì số liệu phải gom về một chỗ.
  static final DiagnosticsService instance = DiagnosticsService._();

  final Stopwatch _uptime = Stopwatch();

  /// Mili-giây mở kho Hive, đo trong `main()`.
  int? hiveInitMs;

  /// Mili-giây mồi bộ từ vựng mẫu ở lần chạy đầu. Null nếu không phải lần đầu.
  int? seedMs;

  /// Mili-giây từ lúc `main()` bắt đầu tới lúc gọi `runApp`.
  int? bootstrapMs;

  final List<TouchSample> _touches = <TouchSample>[];
  final List<DartErrorSample> _dartErrors = <DartErrorSample>[];

  /// 20 lần chạm gần nhất, mới nhất đứng đầu.
  List<TouchSample> get touches => List.unmodifiable(_touches.reversed);

  List<DartErrorSample> get dartErrors => List.unmodifiable(_dartErrors);

  int get uptimeMs => _uptime.elapsedMilliseconds;

  void start() {
    if (!_uptime.isRunning) _uptime.start();
  }

  /// Ghi nhận một lần chạm và đo độ trễ tới khung hình kế tiếp.
  ///
  /// Cách đo: lấy mốc lúc ngón tay chạm xuống, rồi nhờ bộ lập lịch báo lại khi
  /// khung hình sau đó đã vẽ xong. Khoảng cách giữa hai mốc chính là độ trễ mà
  /// người dùng cảm nhận — nếu luồng chính đang bận, khung hình bị hoãn và con
  /// số này phình lên.
  void recordTouch(double x, double y, {List<String> nhanBoi = const []}) {
    final atMs = _uptime.elapsedMilliseconds;
    // Đọc ngay, không đợi tới khung hình sau: tới lúc đó có thể đã có cú chạm
    // khác ghi đè.
    final tho = const WebMetrics().chamThoCuoi;
    final sw = Stopwatch()..start();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      sw.stop();
      // Chỉ giữ 20 mẫu gần nhất: người dùng chỉ cần thấy vài thao tác vừa làm,
      // mà giữ hết thì danh sách phình vô hạn.
      if (_touches.length >= 20) _touches.removeAt(0);
      _touches.add(
        TouchSample(
          atMs: atMs,
          latencyMs: sw.elapsedMilliseconds,
          x: x.round(),
          y: y.round(),
          thoX: tho?.x,
          thoY: tho?.y,
          nhanBoi: nhanBoi,
        ),
      );
    });
    // Bộ lập lịch chỉ gọi lại khi có khung hình mới. Chạm vào chỗ trống không
    // làm gì thì sẽ không có khung nào — phải chủ động yêu cầu vẽ, nếu không
    // mẫu đo sẽ treo lại tới tận thao tác sau và cho ra con số sai bét.
    SchedulerBinding.instance.scheduleFrame();
  }

  void recordDartError(Object error) {
    if (_dartErrors.length >= 20) return;
    _dartErrors.add(
      DartErrorSample(
        atMs: _uptime.elapsedMilliseconds,
        message: error.toString(),
      ),
    );
    // Báo ngay cho dải đỏ, thay vì để nó hỏi lại theo nhịp.
    notifyListeners();
  }

  /// Bắt mọi lỗi của Flutter để hiện lên màn hình chẩn đoán.
  void hookFlutterErrors() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      recordDartError(details.exception);
      previous?.call(details);
    };
  }
}
