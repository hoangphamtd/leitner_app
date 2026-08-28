import '../models/session_state.dart';

/// Cổng đọc ghi trạng thái buổi học đang dở.
///
/// Chỉ có tối đa một buổi dở tại một thời điểm, nên không cần khoá theo mã.
abstract class SessionStateRepository {
  Future<void> init();

  /// Buổi dở đã lưu, hoặc null nếu không có.
  Future<SessionState?> load();

  Future<void> save(SessionState state);

  /// Xoá buổi dở. Gọi khi buổi học kết thúc hoặc khi người học chọn học lại.
  Future<void> clear();
}
