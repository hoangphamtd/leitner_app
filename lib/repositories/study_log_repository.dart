import '../models/study_log.dart';

/// Cổng đọc ghi nhật ký học.
///
/// Tách riêng khỏi `CardRepository` vì hai kho có vòng đời khác hẳn nhau: kho
/// thẻ bị sửa và xoá thường xuyên, còn nhật ký chỉ ghi thêm và giữ vĩnh viễn.
abstract class StudyLogRepository {
  Future<void> init();

  /// Ghi thêm một dòng nhật ký.
  Future<void> append(StudyLog log);

  /// Toàn bộ nhật ký, dùng cho phần xuất sao lưu.
  Future<List<StudyLog>> getAll();

  /// Nhật ký trong khoảng [from] đến [to], dùng cho thống kê.
  Future<List<StudyLog>> getInRange(DateTime from, DateTime to);

  /// Nhật ký của riêng một thẻ.
  Future<List<StudyLog>> getByCardId(String cardId);

  Future<void> clear();
}
