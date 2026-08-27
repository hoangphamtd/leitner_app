import 'package:hive_ce/hive.dart';

part 'study_log.g.dart';

/// Một dòng nhật ký, ghi lại đúng một lượt người học bấm ĐÚNG hoặc SAI.
///
/// Nhật ký chỉ ghi thêm, không bao giờ sửa hay xoá — nhờ vậy phần thống kê sau
/// này luôn dựng lại được lịch sử thật, kể cả khi thẻ đã bị xoá khỏi thư viện.
@HiveType(typeId: 1)
class StudyLog {
  @HiveField(0)
  final String id;

  /// Trỏ tới [Flashcard.id]. Cố ý KHÔNG dùng khoá ngoại thật: thẻ bị xoá thì
  /// dòng nhật ký vẫn còn, chỉ là không tra ngược được nữa.
  @HiveField(1)
  final String cardId;

  @HiveField(2)
  final DateTime answeredAt;

  @HiveField(3)
  final bool isCorrect;

  /// Hộp của thẻ TRƯỚC lượt trả lời này.
  @HiveField(4)
  final int boxBefore;

  /// Hộp của thẻ SAU lượt trả lời này.
  ///
  /// Khi người học sửa được lỗi ngay trong buổi (lượt đúng sau khi đã sai), hai
  /// trường này đều bằng 1 — vì luật ở mục 3.4 quy định lượt sửa sai không được
  /// tính là lên hộp.
  @HiveField(5)
  final int boxAfter;

  const StudyLog({
    required this.id,
    required this.cardId,
    required this.answeredAt,
    required this.isCorrect,
    required this.boxBefore,
    required this.boxAfter,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'cardId': cardId,
        'answeredAt': answeredAt.toIso8601String(),
        'isCorrect': isCorrect,
        'boxBefore': boxBefore,
        'boxAfter': boxAfter,
      };

  factory StudyLog.fromJson(Map<String, dynamic> json) => StudyLog(
        id: json['id'] as String,
        cardId: json['cardId'] as String,
        answeredAt: DateTime.parse(json['answeredAt'] as String),
        isCorrect: json['isCorrect'] as bool,
        boxBefore: json['boxBefore'] as int,
        boxAfter: json['boxAfter'] as int,
      );

  @override
  String toString() =>
      'StudyLog($cardId, ${isCorrect ? "đúng" : "sai"}, $boxBefore→$boxAfter)';
}
