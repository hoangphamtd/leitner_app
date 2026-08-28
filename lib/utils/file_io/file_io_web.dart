import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Tải file xuống và chọn file trên trình duyệt.
///
/// Dùng thẳng API của trình duyệt qua `package:web`. Cố ý không kéo thêm gói
/// chọn file nào: ứng dụng chỉ chạy trên web nên hai thao tác này chỉ là vài
/// dòng, mà thêm gói thì thêm một chuỗi phụ thuộc phải bảo trì.
class FileIo {
  const FileIo();

  /// Tạo file rồi kích hoạt tải xuống.
  ///
  /// Cách làm: gói nội dung vào một Blob, tạo URL tạm trỏ tới nó, rồi bấm hộ
  /// người dùng vào một thẻ liên kết ẩn. Phải thu hồi URL tạm sau khi dùng, nếu
  /// không mỗi lần xuất lại giữ thêm một bản sao trong bộ nhớ cho tới lúc đóng
  /// tab.
  Future<void> download({
    required String fileName,
    required String content,
    String mimeType = 'application/json',
  }) async {
    final blob = web.Blob(
      <JSAny>[content.toJS].toJS,
      web.BlobPropertyBag(type: '$mimeType;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..style.display = 'none';

    web.document.body!.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }

  /// Mở hộp thoại chọn file và đọc nội dung dạng văn bản.
  ///
  /// Trả về null khi người dùng đóng hộp thoại mà không chọn gì.
  Future<String?> pickTextFile({String accept = '.json'}) async {
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = accept
      ..style.display = 'none';

    web.document.body!.appendChild(input);
    final completer = Completer<String?>();

    input.onchange = (web.Event event) {
      final files = input.files;
      if (files == null || files.length == 0) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final reader = web.FileReader();
      reader.onload = (web.Event event) {
        if (completer.isCompleted) return;
        final result = reader.result;
        completer.complete(
          result.isA<JSString>() ? (result! as JSString).toDart : null,
        );
      }.toJS;
      reader.onerror = (web.Event event) {
        if (!completer.isCompleted) {
          completer.completeError(
            const FormatException('Không đọc được nội dung file'),
          );
        }
      }.toJS;
      reader.readAsText(files.item(0)!);
    }.toJS;

    // Trình duyệt cũ KHÔNG bắn sự kiện nào khi người dùng bấm Huỷ. Bản mới có
    // sự kiện 'cancel'; nơi nào chưa hỗ trợ thì Future này đơn giản là không
    // hoàn tất — vẫn an toàn, vì chưa chọn file thì không có gì bị ghi đè.
    input.addEventListener(
      'cancel',
      (web.Event event) {
        if (!completer.isCompleted) completer.complete(null);
      }.toJS,
    );

    input.click();
    try {
      return await completer.future;
    } finally {
      input.remove();
    }
  }
}
