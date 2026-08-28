import 'dart:js_interop';
// Cần cho `getProperty`: `navigator.standalone` là thuộc tính riêng của Safari,
// không nằm trong chuẩn nên phải đọc động.
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../../widgets/install_guide_sheet.dart';

/// Nhận biết môi trường trình duyệt, phục vụ lời mời cài app.
class PlatformInfo {
  const PlatformInfo();

  String get _userAgent => web.window.navigator.userAgent.toLowerCase();

  /// Hệ điều hành di động đang dùng.
  ///
  /// iPad đời mới báo user agent giống máy tính Mac, nên phải kiểm tra thêm khả
  /// năng chạm — không thì người dùng iPad sẽ nhận hướng dẫn sai.
  MobilePlatform get mobilePlatform {
    final agent = _userAgent;
    if (agent.contains('android')) return MobilePlatform.android;
    if (agent.contains('iphone') ||
        agent.contains('ipad') ||
        agent.contains('ipod')) {
      return MobilePlatform.ios;
    }
    if (agent.contains('macintosh') &&
        web.window.navigator.maxTouchPoints > 1) {
      return MobilePlatform.ios;
    }
    return MobilePlatform.other;
  }

  bool get isMobileBrowser => mobilePlatform != MobilePlatform.other;

  /// App đã được cài vào màn hình chính hay chưa.
  ///
  /// Hai cách nhận biết, vì mỗi hệ một kiểu: Android và trình duyệt nền Chromium
  /// đặt chế độ hiển thị thành `standalone`, còn Safari trên iOS đặt thuộc tính
  /// riêng `navigator.standalone`.
  bool get isInstalled {
    final displayMode = web.window.matchMedia('(display-mode: standalone)');
    if (displayMode.matches) return true;

    // `navigator.standalone` là thuộc tính riêng của Safari, không có trong
    // chuẩn nên `package:web` không khai báo sẵn. Phải đọc động qua JSObject.
    final navigator = web.window.navigator as JSObject;
    final standalone = navigator.getProperty<JSAny?>('standalone'.toJS);
    return standalone.isA<JSBoolean>() && (standalone! as JSBoolean).toDart;
  }
}
