// Khoá lại những quy ước của `web/index.html` mà nếu phá là app hỏng trên
// điện thoại — nhưng lại KHÔNG có bài test widget nào bắt được.
//
// Lý do phải kiểm bằng cách đọc thẳng file: lỗi nằm ở tầng trình duyệt, giữa
// nơi trình duyệt báo toạ độ chạm và nơi Flutter vẽ. Test widget chạy trên máy
// ảo Dart, không có trình duyệt, nên không tài nào dựng lại được. Thứ duy nhất
// kiểm được tự động là bản thân nội dung file.
//
// Chuyện đã xảy ra thật (28/08/2026): app cài vào màn hình chính iPhone thì
// mọi nút đều bấm trượt, phải chạm cao hơn khoảng 47 điểm ảnh mới trúng. Mất
// nhiều lượt điều tra mới lần ra hai dòng dưới đây.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Bỏ chú thích HTML và JS trước khi soi nội dung.
///
/// Cần thiết vì chính chú thích trong hai file đó có nhắc tên những thứ bị cấm,
/// để giải thích vì sao chúng bị cấm. Soi cả chú thích thì test đỏ oan, mà xoá
/// chú thích đi thì mất luôn lời giải thích — người sau lại đặt chúng vào.
String _boChuThich(String nguon) => nguon
    .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
    .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');

void main() {
  late String html;

  setUpAll(() {
    html = _boChuThich(File('web/index.html').readAsStringSync());
  });

  group('web/index.html — những dòng không được phép quay lại', () {
    test('KHÔNG được khai báo thẻ <meta name="viewport">', () {
      // Engine của Flutter XOÁ mọi thẻ viewport có sẵn rồi tự đặt lại thẻ của
      // nó — xem `full_page_embedding_strategy.dart`, hàm `_applyViewportMeta`.
      // Cảnh báo về việc đó nằm trong `assert()` nên bản phát hành im lặng.
      //
      // Khai báo thẻ này khiến trang bị bố trí HAI LẦN với hai vùng an toàn
      // khác nhau. Trên iPhone ở chế độ đã cài vào màn hình chính, vùng vẽ và
      // vùng nhận chạm lệch nhau đúng bằng chiều cao thanh trạng thái.
      expect(
        RegExp(r'''<meta\s+name=["']viewport["']''').hasMatch(html),
        isFalse,
        reason:
            'Flutter tự quản thẻ viewport và sẽ xoá thẻ này lúc khởi động. '
            'Khai báo nó chỉ làm trang bị bố trí lại giữa chừng, khiến vùng vẽ '
            'và vùng nhận chạm lệch nhau trên iPhone.',
      );
    });

    test('Thanh trạng thái iOS phải là `black`, KHÔNG phải `black-translucent`', () {
      // `black-translucent` cho web view trườn lên dưới thanh trạng thái, nhưng
      // nội dung vẫn được vẽ bên dưới thanh đó — hai hệ toạ độ không còn chung
      // gốc. Mẫu gốc của Flutter dùng `black`; đừng đổi.
      expect(
        html,
        contains(
          '<meta name="apple-mobile-web-app-status-bar-style" content="black">',
        ),
      );
      expect(
        html.contains('black-translucent'),
        isFalse,
        reason:
            '`black-translucent` là nửa còn lại của lỗi lệch vùng chạm trên '
            'iPhone ở chế độ đã cài vào màn hình chính.',
      );
    });

    test('Không được đặt lề hay đệm cho html/body', () {
      // Engine đặt body thành `position: fixed` phủ kín khung nhìn. Thêm lề hay
      // đệm ở đây là chèn một khoảng trống giữa gốc khung nhìn và gốc vùng vẽ —
      // đúng cái cơ chế đã làm mọi nút bấm trượt.
      final css = RegExp(r'html,\s*body\s*\{([^}]*)\}')
          .firstMatch(html)
          ?.group(1);
      expect(css, isNotNull, reason: 'Không tìm thấy khối CSS cho html, body');
      expect(css, contains('margin: 0'));
      expect(css, contains('padding: 0'));
    });
  });

  group('web/index.html — máy đo phải còn nguyên', () {
    test('Vẫn ghi lại toạ độ thô của trình duyệt', () {
      // Đây là thứ duy nhất cho biết vùng vẽ và vùng chạm có lệch nhau không
      // trên máy thật. Gỡ đi là mù lại.
      expect(html, contains("window.__leitner.chamThoCuoi"));
      expect(html, contains("addEventListener('pointerdown'"));
    });

    test('Chỉ báo có bản mới khi trang VỐN đã được service worker phục vụ', () {
      // Thiếu bảo vệ này thì lần cài đầu tiên cũng bị báo "Có bản cập nhật",
      // vì `clients.claim()` trong sw.js cũng bắn ra `controllerchange`.
      expect(
        html,
        contains(
          'var coNguoiPhucVuTuDau = !!navigator.serviceWorker.controller;',
        ),
      );
      expect(html, contains('if (!coNguoiPhucVuTuDau) return;'));
    });

    test('Vẫn chụp hash lúc mở trang, cho đường #debug', () {
      expect(html, contains('hashBanDau: window.location.hash'));
    });
  });

  group('web/flutter_bootstrap.js', () {
    test('Gọi load() KHÔNG tham số, để Flutter đừng đăng ký service worker', () {
      final js = _boChuThich(
        File('web/flutter_bootstrap.js').readAsStringSync(),
      );
      expect(js, contains('_flutter.loader.load();'));
      expect(
        js.contains('serviceWorkerSettings'),
        isFalse,
        reason:
            'Truyền serviceWorkerSettings sẽ khiến Flutter đăng ký service '
            'worker đã bị khai tử của nó, chiếm mất phạm vi rồi gỡ luôn sw.js.',
      );
    });
  });
}
