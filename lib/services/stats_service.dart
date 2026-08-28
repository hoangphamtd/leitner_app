import '../models/flashcard.dart';
import '../models/study_log.dart';
import '../utils/date_utils.dart' as du;

/// Tính các số liệu hiển thị ở màn hình Tổng quan.
///
/// Cũng như [LeitnerService], lớp này thuần dữ liệu vào — dữ liệu ra, không đọc
/// ghi kho và không biết gì về giao diện, nên kiểm thử được bằng unit test.
class StatsService {
  const StatsService();

  /// Hộp cuối cùng. Thẻ nằm ở đây được coi là ĐÃ THUỘC.
  static const int masteredBox = 5;

  /// Số từ đã thuộc.
  ///
  /// Định nghĩa do người dùng chốt: thẻ đang ở Hộp 5 thì tính là đã thuộc,
  /// không kèm điều kiện nào khác. Thẻ chưa kích hoạt thì không tính, vì nó còn
  /// nằm trong thư viện chứ chưa vào vòng học.
  int countMastered(List<Flashcard> cards) => cards
      .where((card) => card.isActive && card.boxNumber == masteredBox)
      .length;

  /// Chuỗi ngày học liên tiếp.
  ///
  /// Một ngày được tính là "có học" khi có ít nhất một dòng nhật ký trong ngày
  /// đó. Cách đếm: lùi dần từ hôm nay, gặp ngày trống thì dừng.
  ///
  /// Riêng ngày hôm nay được xử lý khoan dung: nếu hôm nay chưa học nhưng hôm
  /// qua có, chuỗi vẫn được giữ nguyên thay vì rơi về 0. Lý do là người học
  /// thường mở app vào buổi tối — nếu sáng ra đã thấy chuỗi bị xoá thì con số
  /// này mất hết tác dụng động viên. Chuỗi chỉ thật sự đứt khi trọn một ngày
  /// trôi qua mà không có lượt ôn nào.
  int calculateStreak(List<StudyLog> logs, DateTime today) {
    if (logs.isEmpty) return 0;

    // Gom về tập các ngày có học, để tra cứu nhanh và không đếm trùng.
    final studiedDays = <DateTime>{
      for (final log in logs) du.DateUtils.startOfDay(log.answeredAt),
    };

    final startOfToday = du.DateUtils.startOfDay(today);
    // Hôm nay chưa học thì bắt đầu đếm từ hôm qua.
    var cursor = studiedDays.contains(startOfToday)
        ? startOfToday
        : du.DateUtils.addDays(startOfToday, -1);

    var streak = 0;
    while (studiedDays.contains(cursor)) {
      streak++;
      cursor = du.DateUtils.addDays(cursor, -1);
    }
    return streak;
  }

  /// Các hộp đang có thẻ đến hạn tính đến hết ngày [day].
  ///
  /// Màn hình Tổng quan dùng tập này để làm nổi bật đúng những khối cần chú ý.
  Set<int> boxesDueOn(List<Flashcard> cards, DateTime day) {
    final cutoff = du.DateUtils.endOfDay(day);
    return {
      for (final card in cards)
        if (card.isActive && !card.nextReviewDate.isAfter(cutoff))
          card.boxNumber,
    };
  }
}
