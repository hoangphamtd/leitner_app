import 'package:hive_ce/hive.dart';

import '../utils/date_utils.dart' as du;

part 'app_settings.g.dart';

/// Chế độ giao diện sáng/tối.
///
/// PHẢI có `@HiveType` riêng. Hive không tự biết cách ghi một enum: thiếu adapter
/// thì lúc lưu sẽ ném `HiveError: Cannot write, unknown type`. Lỗi này chỉ hiện
/// ra khi ghi thật xuống kho, nên unit test dùng repository giả không bắt được —
/// đã vấp đúng một lần khi chạy thử trên trình duyệt.
///
/// TUYỆT ĐỐI không đổi số `@HiveField` của các giá trị đã có, chỉ được thêm giá
/// trị mới vào cuối với số mới — đổi số sẽ khiến cài đặt đã lưu của người dùng
/// bị đọc nhầm sang chế độ khác.
@HiveType(typeId: 4)
enum AppThemeMode {
  @HiveField(0)
  system,
  @HiveField(1)
  light,
  @HiveField(2)
  dark,
}

/// Cài đặt của ứng dụng.
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

  /// Mã giọng đọc do người dùng chọn, ví dụ `en-US-x-sfg#male_1-local`.
  ///
  /// Null nghĩa là dùng giọng mặc định của hệ điều hành. Giọng có sẵn khác nhau
  /// trên từng máy và từng trình duyệt, nên giọng đã lưu có thể không còn tồn
  /// tại — `PronunciationService` phải tự lùi về giọng mặc định trong trường hợp
  /// đó thay vì báo lỗi.
  @HiveField(3)
  final String? ttsVoiceName;

  /// Ngôn ngữ của giọng đã chọn. Đi cặp với [ttsVoiceName] vì API đặt giọng của
  /// `flutter_tts` cần cả hai.
  @HiveField(4)
  final String? ttsVoiceLocale;

  /// Tốc độ đọc, từ 0 tới 1. Mặc định 0.45 — chậm hơn mức thường của hệ điều
  /// hành, để người học nghe rõ từng âm.
  @HiveField(5)
  final double ttsRate;

  /// Chế độ giao diện sáng/tối.
  @HiveField(6)
  final AppThemeMode themeMode;

  /// Lần xuất sao lưu gần nhất. Null nghĩa là chưa xuất lần nào.
  ///
  /// Toàn bộ dữ liệu học nằm trong IndexedDB của trình duyệt, mà trình duyệt có
  /// quyền dọn kho đó bất cứ lúc nào — nhất là khi máy hết dung lượng hoặc người
  /// dùng xoá dữ liệu duyệt web. Vì vậy mốc này được dùng để nhắc sao lưu định
  /// kỳ ở màn hình Tổng quan.
  @HiveField(7)
  final DateTime? lastBackupAt;

  /// Lần gần nhất người dùng bỏ qua lời mời cài app vào màn hình chính.
  ///
  /// Null nghĩa là chưa từng bỏ qua. Dùng để nhắc lại sau ba ngày thay vì hỏi
  /// lại mỗi lần mở app.
  @HiveField(8)
  final DateTime? installPromptDismissedAt;

  const AppSettings({
    this.newCardsPerDay = 20,
    this.lastActivationDate,
    this.activatedCountToday = 0,
    this.ttsVoiceName,
    this.ttsVoiceLocale,
    this.ttsRate = 0.45,
    this.themeMode = AppThemeMode.system,
    this.lastBackupAt,
    this.installPromptDismissedAt,
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

  /// Tạo bản sao đã sửa vài trường.
  ///
  /// Hai trường giọng đọc dùng cờ `clearTtsVoice` riêng, vì truyền null vào đây
  /// mang nghĩa "giữ nguyên" chứ không phải "xoá giọng đã chọn".
  AppSettings copyWith({
    int? newCardsPerDay,
    DateTime? lastActivationDate,
    int? activatedCountToday,
    String? ttsVoiceName,
    String? ttsVoiceLocale,
    bool clearTtsVoice = false,
    double? ttsRate,
    AppThemeMode? themeMode,
    DateTime? lastBackupAt,
    DateTime? installPromptDismissedAt,
  }) {
    return AppSettings(
      newCardsPerDay: newCardsPerDay ?? this.newCardsPerDay,
      lastActivationDate: lastActivationDate ?? this.lastActivationDate,
      activatedCountToday: activatedCountToday ?? this.activatedCountToday,
      ttsVoiceName: clearTtsVoice ? null : (ttsVoiceName ?? this.ttsVoiceName),
      ttsVoiceLocale: clearTtsVoice
          ? null
          : (ttsVoiceLocale ?? this.ttsVoiceLocale),
      ttsRate: ttsRate ?? this.ttsRate,
      themeMode: themeMode ?? this.themeMode,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      installPromptDismissedAt:
          installPromptDismissedAt ?? this.installPromptDismissedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'newCardsPerDay': newCardsPerDay,
    'lastActivationDate': lastActivationDate?.toIso8601String(),
    'activatedCountToday': activatedCountToday,
    'ttsVoiceName': ttsVoiceName,
    'ttsVoiceLocale': ttsVoiceLocale,
    'ttsRate': ttsRate,
    'themeMode': themeMode.name,
    'lastBackupAt': lastBackupAt?.toIso8601String(),
    'installPromptDismissedAt': installPromptDismissedAt?.toIso8601String(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final rawDate = json['lastActivationDate'] as String?;
    final rawTheme = json['themeMode'] as String?;
    final rawBackup = json['lastBackupAt'] as String?;
    final rawDismissed = json['installPromptDismissedAt'] as String?;
    return AppSettings(
      newCardsPerDay: json['newCardsPerDay'] as int? ?? 20,
      lastActivationDate: rawDate == null ? null : DateTime.parse(rawDate),
      activatedCountToday: json['activatedCountToday'] as int? ?? 0,
      ttsVoiceName: json['ttsVoiceName'] as String?,
      ttsVoiceLocale: json['ttsVoiceLocale'] as String?,
      ttsRate: (json['ttsRate'] as num?)?.toDouble() ?? 0.45,
      // File sao lưu có thể đến từ bản cũ hơn hoặc bị sửa tay, nên tên chế độ
      // lạ thì lùi về mặc định thay vì ném lỗi làm hỏng cả lượt nhập.
      themeMode: AppThemeMode.values.firstWhere(
        (mode) => mode.name == rawTheme,
        orElse: () => AppThemeMode.system,
      ),
      lastBackupAt: rawBackup == null ? null : DateTime.parse(rawBackup),
      installPromptDismissedAt: rawDismissed == null
          ? null
          : DateTime.parse(rawDismissed),
    );
  }
}
