/// Toạ độ THÔ của cú chạm gần nhất, do chính trình duyệt báo.
///
/// Dùng để đối chiếu với toạ độ mà Flutter tính ra cho cùng cú chạm. Hai con số
/// này phải bằng nhau; lệch nhau nghĩa là vùng vẽ và vùng nhận chạm không cùng
/// một hệ toạ độ, và người dùng sẽ bấm trượt đúng bằng độ lệch đó.
class ChamTho {
  final int x;
  final int y;

  /// Kích thước vùng nhìn thấy ngay lúc chạm, để biết trang có bị bố trí lại
  /// giữa chừng không.
  final int rongCuaSo;
  final int caoCuaSo;

  const ChamTho({
    required this.x,
    required this.y,
    required this.rongCuaSo,
    required this.caoCuaSo,
  });
}

/// Một lỗi JavaScript bắt được ở tầng trình duyệt.
class JsError {
  /// Số mili-giây kể từ lúc mở trang.
  final int luc;
  final String nguon;
  final String thongDiep;
  final String? chiTiet;

  const JsError({
    required this.luc,
    required this.nguon,
    required this.thongDiep,
    this.chiTiet,
  });
}

/// Bản dự phòng cho môi trường không phải trình duyệt (unit test chạy trên máy
/// ảo Dart). Trả về giá trị rỗng để màn hình chẩn đoán vẫn dựng được.
class WebMetrics {
  const WebMetrics();

  /// Mili-giây từ lúc mở trang tới khung hình đầu tiên. Null nếu chưa vẽ xong.
  int? get firstFrameMs => null;

  /// Mili-giây đã trôi qua kể từ lúc mở trang.
  int get uptimeMs => 0;

  /// Toạ độ thô của cú chạm gần nhất. Null khi không chạy trên trình duyệt.
  ChamTho? get chamThoCuoi => null;

  List<JsError> get jsErrors => const [];

  /// Bộ vẽ đang chạy: 'canvaskit', 'skwasm', hoặc 'khong ro'.
  String get renderer => 'khong chay tren web';

  int get hardwareConcurrency => 0;

  /// Bộ nhớ máy ước tính, đơn vị GB. 0 nghĩa là trình duyệt không cho biết.
  double get deviceMemoryGb => 0;

  String get userAgent => 'khong chay tren web';

  /// Đường dẫn phân đoạn hiện tại, ví dụ `#debug`.
  String get locationHash => '';

  bool get isStandalone => false;

  /// Mã build đang chạy. `__BUILD_VERSION__` nghĩa là bản chạy ở máy phát triển.
  String get buildVersion => 'dev';

  /// Đã có bản mới tải xong, chỉ chờ tải lại trang để thay thế.
  bool get hasUpdate => false;

  /// Giục service worker mới vào việc rồi tải lại trang.
  void applyUpdate() {}

  /// Phần đuôi địa chỉ ngay lúc mở trang, chụp trước khi Flutter ghi đè.
  String get initialHash => '';

  /// Cách app đang được mở: 'browser', 'standalone', 'standalone-ios'…
  String get displayMode => 'khong chay tren web';

  /// Đang chạy ở chế độ đã cài vào màn hình chính.
  bool get isStandaloneMode => false;

  /// Lỗi của những phiên chạy trước, đọc lại từ kho của trình duyệt.
  List<JsError> get previousSessionErrors => const [];

  /// Xoá nhật ký lỗi sau khi người dùng đã xem.
  void clearErrors() {}

  /// Đăng ký hàm được gọi mỗi khi phía trình duyệt ghi thêm một lỗi.
  void onJsError(void Function() callback) {}

  /// Đăng ký hàm được gọi khi phát hiện có bản cập nhật.
  void onUpdateAvailable(void Function() callback) {}
}
