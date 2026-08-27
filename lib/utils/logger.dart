import 'dart:developer' as developer;

/// Mức độ nghiêm trọng của một dòng nhật ký.
enum LogLevel { debug, info, warning, error }

/// Lớp ghi nhật ký tối giản, dùng thay cho `print`.
///
/// Lý do không dùng `print`: trên bản build phát hành, `print` vẫn in ra console
/// trình duyệt và có thể để lộ dữ liệu người học. Ở đây mọi thứ đi qua
/// `dart:developer`, và có thể tắt sạch bằng [minimumLevel].
class Logger {
  /// Tên vùng, thường là tên lớp gọi tới. Giúp lọc nhật ký khi soi lỗi.
  final String tag;

  const Logger(this.tag);

  /// Ngưỡng lọc chung cho toàn ứng dụng. Nâng lên [LogLevel.warning] khi phát
  /// hành để console gọn.
  static LogLevel minimumLevel = LogLevel.debug;

  void debug(String message) => _write(LogLevel.debug, message);

  void info(String message) => _write(LogLevel.info, message);

  void warning(String message) => _write(LogLevel.warning, message);

  /// Ghi lỗi kèm nguyên nhân gốc và vết gọi hàm.
  ///
  /// Luôn truyền [error] vào đây thay vì nhét vào chuỗi [message], vì như vậy
  /// công cụ gỡ lỗi mới hiển thị được vết gọi hàm đầy đủ.
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _write(LogLevel.error, message, error, stackTrace);

  void _write(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (level.index < minimumLevel.index) return;
    developer.log(
      message,
      name: '${level.name.toUpperCase()}/$tag',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
