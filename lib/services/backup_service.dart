import 'dart:convert';

import '../models/app_settings.dart';
import '../models/flashcard.dart';
import '../models/study_log.dart';
import '../utils/logger.dart';

/// Toàn bộ dữ liệu của một lần sao lưu.
class BackupData {
  final List<Flashcard> cards;
  final List<StudyLog> logs;
  final AppSettings settings;

  const BackupData({
    required this.cards,
    required this.logs,
    required this.settings,
  });
}

/// Kết quả kiểm tra một file sao lưu trước khi ghi đè.
class BackupPreview {
  final int cardCount;
  final int logCount;
  final DateTime? exportedAt;
  final int formatVersion;

  const BackupPreview({
    required this.cardCount,
    required this.logCount,
    required this.exportedAt,
    required this.formatVersion,
  });
}

/// Lỗi khi đọc file sao lưu.
///
/// Tách riêng khỏi [FormatException] để giao diện phân biệt được "file hỏng"
/// với các lỗi khác và hiện đúng thông báo cho người dùng.
class BackupException implements Exception {
  final String message;

  const BackupException(this.message);

  @override
  String toString() => message;
}

/// Gom dữ liệu thành file JSON và đọc ngược lại.
///
/// Lớp này thuần dữ liệu vào — dữ liệu ra: nó KHÔNG đọc kho và KHÔNG tải file.
/// Việc tải xuống hay chọn file thuộc về tầng giao diện, việc đọc ghi kho thuộc
/// về repository. Nhờ vậy toàn bộ phần định dạng file kiểm thử được bằng unit
/// test thường, không cần trình duyệt.
class BackupService {
  const BackupService();

  /// Số phiên bản định dạng file.
  ///
  /// Tăng số này mỗi khi cấu trúc file đổi theo cách không đọc ngược được. Hàm
  /// nhập kiểm tra số này TRƯỚC khi ghi đè, để một file của bản tương lai không
  /// âm thầm phá dữ liệu của bản cũ.
  static const int formatVersion = 1;

  /// Tên file gợi ý, dạng `leitner-backup-YYYYMMDD.json`.
  String suggestedFileName(DateTime now) {
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'leitner-backup-$y$m$d.json';
  }

  /// Gom toàn bộ dữ liệu thành chuỗi JSON.
  String export(BackupData data, {DateTime? now}) {
    final moment = now ?? DateTime.now();
    final payload = {
      'formatVersion': formatVersion,
      'exportedAt': moment.toIso8601String(),
      'appName': 'leitner_app',
      'settings': data.settings.toJson(),
      'cards': [for (final card in data.cards) card.toJson()],
      'logs': [for (final log in data.logs) log.toJson()],
    };
    // Xuống dòng và thụt lề để người dùng mở file ra còn đọc được, và để phần
    // khác biệt giữa hai bản sao lưu nhìn ra được bằng mắt.
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Đọc phần đầu file để hiển thị cho người dùng xác nhận TRƯỚC khi ghi đè.
  BackupPreview preview(String rawJson) {
    final map = _decodeRoot(rawJson);
    return BackupPreview(
      cardCount: (map['cards'] as List?)?.length ?? 0,
      logCount: (map['logs'] as List?)?.length ?? 0,
      exportedAt: _parseDate(map['exportedAt']),
      formatVersion: map['formatVersion'] as int? ?? 0,
    );
  }

  /// Đọc trọn file sao lưu.
  ///
  /// Ném [BackupException] khi file hỏng hoặc thuộc phiên bản định dạng mới hơn
  /// bản đang chạy. Tuyệt đối không cố "đọc được đến đâu hay đến đó": nhập nửa
  /// vời sẽ để lại một kho dữ liệu vừa mất thẻ vừa sai tiến độ, mà người dùng
  /// lại tưởng là đã khôi phục xong.
  BackupData import(String rawJson) {
    final map = _decodeRoot(rawJson);

    final version = map['formatVersion'] as int? ?? 0;
    if (version > formatVersion) {
      throw BackupException(
        'File sao lưu thuộc định dạng phiên bản $version, '
        'mới hơn bản ứng dụng đang chạy (phiên bản $formatVersion). '
        'Hãy cập nhật ứng dụng rồi nhập lại.',
      );
    }
    if (version < 1) {
      throw const BackupException(
        'File không phải bản sao lưu của ứng dụng này.',
      );
    }

    final rawCards = map['cards'];
    if (rawCards is! List) {
      throw const BackupException('File thiếu danh sách thẻ.');
    }

    final cards = <Flashcard>[];
    for (var index = 0; index < rawCards.length; index++) {
      final entry = rawCards[index];
      if (entry is! Map) {
        throw BackupException('Thẻ thứ ${index + 1} trong file bị hỏng.');
      }
      try {
        cards.add(Flashcard.fromJson(Map<String, dynamic>.from(entry)));
      } on FormatException catch (error) {
        throw BackupException(
          'Thẻ thứ ${index + 1} trong file bị hỏng: ${error.message}',
        );
      }
    }

    final logs = <StudyLog>[];
    final rawLogs = map['logs'];
    if (rawLogs is List) {
      for (final entry in rawLogs) {
        if (entry is! Map) continue;
        try {
          logs.add(StudyLog.fromJson(Map<String, dynamic>.from(entry)));
        } catch (error) {
          // Nhật ký chỉ phục vụ thống kê. Một dòng hỏng thì bỏ dòng đó, không
          // đáng để huỷ cả lượt khôi phục thẻ — khác hẳn với thẻ ở trên.
          const Logger('BackupService').warning('Bỏ qua một dòng nhật ký hỏng');
        }
      }
    }

    final rawSettings = map['settings'];
    final settings = rawSettings is Map
        ? AppSettings.fromJson(Map<String, dynamic>.from(rawSettings))
        : const AppSettings();

    return BackupData(cards: cards, logs: logs, settings: settings);
  }

  /// Đã quá hạn nhắc sao lưu chưa.
  ///
  /// Quá [thresholdDays] ngày kể từ lần xuất gần nhất thì nhắc. Chưa xuất lần
  /// nào cũng tính là cần nhắc, nhưng chỉ khi người học đã có dữ liệu đáng để
  /// mất — nhắc một kho rỗng thì vô nghĩa và chỉ gây phiền.
  bool shouldRemindBackup({
    required DateTime? lastBackupAt,
    required int cardCount,
    required DateTime now,
    int thresholdDays = 14,
  }) {
    if (cardCount == 0) return false;
    if (lastBackupAt == null) return true;
    return now.difference(lastBackupAt).inDays >= thresholdDays;
  }

  Map<String, dynamic> _decodeRoot(String rawJson) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException catch (error) {
      throw BackupException('File không phải JSON hợp lệ: ${error.message}');
    }
    if (decoded is! Map) {
      throw const BackupException('File sao lưu phải là một đối tượng JSON.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  DateTime? _parseDate(Object? raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw);
  }
}
