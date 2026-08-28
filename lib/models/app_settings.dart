import 'package:hive_ce/hive.dart';

import '../utils/date_utils.dart' as du;

part 'app_settings.g.dart';

/// Cài đặt của ứng dụng.
///
/// Giai đoạn 1 mới chỉ dùng tới hạn mức từ mới mỗi ngày (mục 3.6) và bộ đếm đi
/// kèm. Các tuỳ chọn giọng đọc, tốc độ đọc và giao diện sáng/tối sẽ được thêm
/// vào ở giai đoạn sau — Hive cho phép bổ sung trường mà vẫn đọc được dữ liệu
/// cũ, nên không cần khai báo trước ở đây.
@HiveType(typeId: 2)
class AppSettings {
  /// Số thẻ mới tối đa được kích hoạt vào Hộp 1 mỗi ngày. Mặc định 20.
  @HiveField(0)
  final int newCardsPerDay;

  /// Ngày gần nhất người học kích hoạt thẻ mới, chuẩn hoá về 00:00.
  ///
  /// Đi cặp với [activatedCountToday] để biết hôm nay đã dùng bao nhiêu suất.
  /// Sở dĩ phải lưu riêng chứ không đếm ngược từ thẻ: thẻ có thể bị sửa hay bị
  /// xoá sau khi kích hoạt, lúc đó đếm ngược sẽ ra số sai.
  @HiveField(1)
  final DateTime? lastActivationDate;

  /// Số thẻ đã kích hoạt trong ngày [lastActivationDate].
  ///
  /// Sang ngày mới thì số này coi như 0 — xem [remainingQuotaOn].
  @HiveField(2)
  final int activatedCountToday;

  const AppSettings({
    this.newCardsPerDay = 20,
    this.lastActivationDate,
    this.activatedCountToday = 0,
  });

  /// Số suất kích hoạt còn lại trong ngày [day].
  ///
  /// Bộ đếm chỉ có ý nghĩa trong đúng ngày đã lưu ở [lastActivationDate]. Sang
  /// ngày mới thì coi như chưa dùng suất nào, nên không cần một tác vụ nền chạy
  /// lúc nửa đêm để đặt lại bộ đếm — cứ so ngày lúc đọc là đủ.
  int remainingQuotaOn(DateTime day) {
    final last = lastActivationDate;
    if (last == null || !du.DateUtils.isSameDay(last, day)) {
      return newCardsPerDay;
    }
    final remaining = newCardsPerDay - activatedCountToday;
    // Chặn số âm phòng khi người học hạ hạn mức xuống thấp hơn số đã kích hoạt.
    return remaining < 0 ? 0 : remaining;
  }

  AppSettings copyWith({
    int? newCardsPerDay,
    DateTime? lastActivationDate,
    int? activatedCountToday,
  }) {
    return AppSettings(
      newCardsPerDay: newCardsPerDay ?? this.newCardsPerDay,
      lastActivationDate: lastActivationDate ?? this.lastActivationDate,
      activatedCountToday: activatedCountToday ?? this.activatedCountToday,
    );
  }

  Map<String, dynamic> toJson() => {
    'newCardsPerDay': newCardsPerDay,
    'lastActivationDate': lastActivationDate?.toIso8601String(),
    'activatedCountToday': activatedCountToday,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final rawDate = json['lastActivationDate'] as String?;
    return AppSettings(
      newCardsPerDay: json['newCardsPerDay'] as int? ?? 20,
      lastActivationDate: rawDate == null ? null : DateTime.parse(rawDate),
      activatedCountToday: json['activatedCountToday'] as int? ?? 0,
    );
  }
}
