import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'web_metrics_stub.dart' show JsError;

export 'web_metrics_stub.dart' show JsError;

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

  List<JsError> get jsErrors {
    final raw = _kho?.getProperty<JSAny?>('loiJS'.toJS);
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

  int _soNguyen(JSObject obj, String key) {
    final value = obj.getProperty<JSAny?>(key.toJS);
    return value.isA<JSNumber>() ? (value! as JSNumber).toDartInt : 0;
  }

  String? _chuoi(JSObject obj, String key) {
    final value = obj.getProperty<JSAny?>(key.toJS);
    return value.isA<JSString>() ? (value! as JSString).toDart : null;
  }
}
