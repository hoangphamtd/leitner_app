import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'web_metrics_stub.dart' show ChamTho, JsError;

export 'web_metrics_stub.dart' show ChamTho, JsError;

/// Đọc các số liệu mà `web/index.html` thu thập được ở tầng trình duyệt.
///
/// Những con số này KHÔNG lấy được từ phía Dart: mốc mở trang xảy ra trước khi
/// Flutter khởi động, và lỗi JavaScript trong lúc nạp cũng xảy ra trước đó.
class WebMetrics {
  const WebMetrics();

  JSObject? get _kho {
    final store = web.window.getProperty<JSAny?>('__leitner'.toJS);
    return store.isA<JSObject>() ? store! as JSObject : null;
  }

  int? get firstFrameMs {
    final value = _kho?.getProperty<JSAny?>('khungDauTien_ms'.toJS);
    if (value.isA<JSNumber>()) return (value! as JSNumber).toDartInt;
    return null;
  }

  int get uptimeMs {
    final moc = _kho?.getProperty<JSAny?>('mocMoTrang'.toJS);
    if (!moc.isA<JSNumber>()) return 0;
    final start = (moc! as JSNumber).toDartDouble;
    return (DateTime.now().millisecondsSinceEpoch - start).round();
  }

  List<JsError> get jsErrors => _docDanhSachLoi('loiJS');

  List<JsError> _docDanhSachLoi(String key) {
    final raw = _kho?.getProperty<JSAny?>(key.toJS);
    if (!raw.isA<JSArray>()) return const [];
    final list = raw! as JSArray;
    final result = <JsError>[];
    for (var i = 0; i < list.length; i++) {
      final item = list.getProperty<JSAny?>(i.toJS);
      if (!item.isA<JSObject>()) continue;
      final obj = item! as JSObject;
      result.add(
        JsError(
          luc: _soNguyen(obj, 'luc'),
          nguon: _chuoi(obj, 'nguon') ?? 'khong ro',
          thongDiep: _chuoi(obj, 'thongDiep') ?? '',
          chiTiet: _chuoi(obj, 'chiTiet'),
        ),
      );
    }
    return result;
  }

  /// Bộ vẽ đang chạy.
  ///
  /// Không có API chính thức để hỏi, nên phải dò dấu vết mà từng bộ vẽ để lại
  /// trên `window`: CanvasKit đặt `flutterCanvasKit`, còn skwasm đặt
  /// `_flutter_skwasmInstance`.
  String get renderer {
    if (web.window.getProperty<JSAny?>('flutterCanvasKit'.toJS) != null) {
      return 'canvaskit';
    }
    if (web.window.getProperty<JSAny?>('_flutter_skwasmInstance'.toJS) !=
        null) {
      return 'skwasm';
    }
    return 'khong ro';
  }

  int get hardwareConcurrency => web.window.navigator.hardwareConcurrency;

  double get deviceMemoryGb {
    final nav = web.window.navigator as JSObject;
    final value = nav.getProperty<JSAny?>('deviceMemory'.toJS);
    if (value.isA<JSNumber>()) return (value! as JSNumber).toDartDouble;
    return 0;
  }

  String get userAgent => web.window.navigator.userAgent;

  String get locationHash => web.window.location.hash;

  /// App đang chạy ở chế độ đã cài vào màn hình chính hay không.
  bool get isStandalone {
    if (web.window.matchMedia('(display-mode: standalone)').matches) {
      return true;
    }
    final nav = web.window.navigator as JSObject;
    final value = nav.getProperty<JSAny?>('standalone'.toJS);
    return value.isA<JSBoolean>() && (value! as JSBoolean).toDart;
  }

  /// Mã build đang chạy.
  ///
  /// Trả về 'dev' khi chuỗi thay thế còn nguyên, tức bản này chưa qua khâu
  /// triển khai — đó chính là dấu hiệu để phân biệt bản máy nhà với bản thật.
  String get buildVersion {
    final value = _kho?.getProperty<JSAny?>('phienBan'.toJS);
    if (!value.isA<JSString>()) return 'khong ro';
    final raw = (value! as JSString).toDart;
    return raw.startsWith('__') ? 'dev' : raw;
  }

  /// Đã có bản mới tải xong, chỉ chờ tải lại trang để thay thế.
  /// Toạ độ thô của cú chạm gần nhất, lấy từ máy đo trong `web/index.html`.
  ChamTho? get chamThoCuoi {
    final value = _kho?.getProperty<JSAny?>('chamThoCuoi'.toJS);
    if (!value.isA<JSObject>()) return null;
    final obj = value! as JSObject;
    return ChamTho(
      x: _soNguyen(obj, 'x'),
      y: _soNguyen(obj, 'y'),
      rongCuaSo: _soNguyen(obj, 'rongCuaSo'),
      caoCuaSo: _soNguyen(obj, 'caoCuaSo'),
    );
  }

  bool get hasUpdate {
    final value = _kho?.getProperty<JSAny?>('coBanMoi'.toJS);
    return value.isA<JSBoolean>() && (value! as JSBoolean).toDart;
  }

  /// Tải lại trang để bản mới có hiệu lực.
  ///
  /// Service worker mới đã chiếm quyền từ trước (nhờ `skipWaiting`), nhưng mã
  /// đang chạy trong trang này là mã cũ đã nạp lúc mở — chỉ tải lại mới đổi được.
  void applyUpdate() => web.window.location.reload();

  /// Phần đuôi địa chỉ NGAY LÚC MỞ TRANG.
  ///
  /// Phải dùng bản chụp sẵn từ `index.html`, không được đọc thẳng
  /// `window.location.hash`: Flutter web quản lý địa chỉ bằng hash và ghi đè nó
  /// thành '#/' khi khởi động, nên đọc muộn là mất sạch.
  String get initialHash {
    final value = _kho?.getProperty<JSAny?>('hashBanDau'.toJS);
    return value.isA<JSString>() ? (value! as JSString).toDart : '';
  }

  /// Cách app đang được mở.
  String get displayMode {
    final value = _kho?.getProperty<JSAny?>('cheDoHienThi'.toJS);
    return value.isA<JSString>() ? (value! as JSString).toDart : 'khong ro';
  }

  bool get isStandaloneMode => displayMode.startsWith('standalone');

  /// Lỗi của các phiên chạy trước.
  List<JsError> get previousSessionErrors => _docDanhSachLoi('loiPhienTruoc');

  /// Xoá nhật ký lỗi.
  void clearErrors() {
    final fn = web.window.getProperty<JSAny?>('__leitnerXoaLoi'.toJS);
    if (fn.isA<JSFunction>()) (fn! as JSFunction).callAsFunction();
  }

  /// Đăng ký hàm được gọi mỗi khi phía trình duyệt ghi thêm một lỗi.
  ///
  /// Dùng cách BÁO SANG thay vì hỏi lại theo nhịp. Hỏi theo nhịp thì cứ đúng
  /// chu kỳ là đánh thức luồng chính dù chẳng có việc gì — trên máy yếu, chỗ
  /// lãng phí đó cộng dồn thành giật.
  void onJsError(void Function() callback) {
    web.window.setProperty('__leitnerBaoLoi'.toJS, callback.toJS);
  }

  /// Đăng ký hàm được gọi khi phát hiện có bản cập nhật.
  void onUpdateAvailable(void Function() callback) {
    web.window.setProperty('__leitnerBaoCapNhat'.toJS, callback.toJS);
  }

  int _soNguyen(JSObject obj, String key) {
    final value = obj.getProperty<JSAny?>(key.toJS);
    return value.isA<JSNumber>() ? (value! as JSNumber).toDartInt : 0;
  }

  String? _chuoi(JSObject obj, String key) {
    final value = obj.getProperty<JSAny?>(key.toJS);
    return value.isA<JSString>() ? (value! as JSString).toDart : null;
  }
}
