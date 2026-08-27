/// Tiện ích ngày tháng dùng chung cho toàn bộ phần lịch ôn tập.
///
/// Cả ứng dụng làm việc theo GIỜ ĐỊA PHƯƠNG của máy người học, không dùng UTC.
/// Lý do: lịch ôn được định nghĩa theo "thứ trong tuần" và "ngày 15 hằng tháng"
/// — đó là những khái niệm theo lịch mà người học nhìn thấy trên tường, nên phải
/// bám theo múi giờ của họ. Nếu quy về UTC thì người ở múi giờ +07 sẽ thấy thẻ
/// đến hạn lệch mất một ngày.
class DateUtils {
  const DateUtils._();

  /// Cắt phần giờ phút giây, trả về đúng 00:00 của ngày đó.
  ///
  /// Dựng lại bằng `DateTime(y, m, d)` chứ không trừ đi số giờ, vì cách trừ sẽ
  /// sai vào những ngày đổi giờ mùa hè (ngày đó có thể dài 23 hoặc 25 tiếng).
  static DateTime startOfDay(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day);

  /// Thời điểm cuối cùng còn thuộc về ngày đó, dùng để so sánh "đến hạn hôm nay".
  static DateTime endOfDay(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day, 23, 59, 59, 999);

  /// Cộng thêm [days] ngày theo lịch, giữ mốc 00:00.
  ///
  /// Dùng `DateTime(y, m, d + days)` thay cho `add(Duration(days: days))` vì lý
  /// do đổi giờ mùa hè nói trên — `Duration` cộng theo số giờ tuyệt đối nên có
  /// thể nhảy sai ngày.
  static DateTime addDays(DateTime moment, int days) =>
      DateTime(moment.year, moment.month, moment.day + days);

  /// Hai thời điểm có rơi vào cùng một ngày lịch hay không.
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
