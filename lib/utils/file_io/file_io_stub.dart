/// Bản dự phòng cho các nền tảng không phải web.
///
/// Ứng dụng chỉ chạy trên trình duyệt, nhưng unit test chạy trên máy ảo Dart —
/// nơi không có `package:web`. Không có bản dự phòng này thì chỉ cần một file
/// test lỡ chạm tới chuỗi phụ thuộc là cả bộ test không biên dịch nổi.
class FileIo {
  const FileIo();

  Future<void> download({
    required String fileName,
    required String content,
    String mimeType = 'application/json',
  }) async {
    throw UnsupportedError('Tải file chỉ hỗ trợ trên trình duyệt');
  }

  Future<String?> pickTextFile({String accept = '.json'}) async {
    throw UnsupportedError('Chọn file chỉ hỗ trợ trên trình duyệt');
  }
}
