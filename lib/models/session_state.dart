import 'package:hive_ce/hive.dart';

part 'session_state.g.dart';

/// Ảnh chụp một buổi học đang dở, đủ để dựng lại y nguyên hàng đợi.
///
/// Người học trên điện thoại rất hay bị ngắt giữa chừng — có cuộc gọi, khoá màn
/// hình, chuyển sang app khác rồi trình duyệt thu hồi bộ nhớ. Không lưu lại thì
/// mất trắng cả buổi học.
///
/// Chỉ lưu MÃ thẻ chứ không lưu bản sao thẻ. Bản thân thẻ đã được ghi xuống kho
/// ngay sau mỗi lượt trả lời rồi; lưu thêm bản sao ở đây sẽ tạo ra hai nguồn sự
/// thật, và khi hai bên lệch nhau thì không biết tin bên nào.
@HiveType(typeId: 3)
class SessionState {
  /// Mã các thẻ còn trong hàng đợi, theo ĐÚNG thứ tự chờ.
  ///
  /// Thứ tự là phần quan trọng nhất: thẻ trả lời sai nằm ở cuối hàng, dựng lại
  /// sai thứ tự thì người học gặp lại thẻ khó không đúng lúc.
  @HiveField(0)
  final List<String> queueCardIds;

  /// Mã các thẻ đã trả lời sai ít nhất một lần trong buổi.
  ///
  /// Bắt buộc phải lưu, nếu không thì sau khi khôi phục, thẻ từng sai sẽ được
  /// coi như chưa sai và lượt đúng kế tiếp lại cho nó lên hộp — vi phạm luật ở
  /// mục 3.4.
  @HiveField(1)
  final List<String> failedCardIds;

  /// Mã các thẻ đã học xong và rời hàng đợi.
  @HiveField(2)
  final List<String> completedCardIds;

  /// Số thẻ lúc buổi học bắt đầu, dùng để vẽ lại thanh tiến độ.
  @HiveField(3)
  final int initialCount;

  @HiveField(4)
  final int correctAnswers;

  @HiveField(5)
  final int wrongAnswers;

  /// Thời điểm bắt đầu buổi học. Dùng để biết buổi dở có phải của hôm nay không.
  @HiveField(6)
  final DateTime startedAt;

  const SessionState({
    required this.queueCardIds,
    required this.failedCardIds,
    required this.completedCardIds,
    required this.initialCount,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.startedAt,
  });

  /// Buổi dở còn thẻ để học tiếp hay không.
  bool get hasWork => queueCardIds.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'queueCardIds': queueCardIds,
    'failedCardIds': failedCardIds,
    'completedCardIds': completedCardIds,
    'initialCount': initialCount,
    'correctAnswers': correctAnswers,
    'wrongAnswers': wrongAnswers,
    'startedAt': startedAt.toIso8601String(),
  };

  factory SessionState.fromJson(Map<String, dynamic> json) => SessionState(
    queueCardIds: List<String>.from(json['queueCardIds'] as List),
    failedCardIds: List<String>.from(json['failedCardIds'] as List),
    completedCardIds: List<String>.from(json['completedCardIds'] as List),
    initialCount: json['initialCount'] as int,
    correctAnswers: json['correctAnswers'] as int,
    wrongAnswers: json['wrongAnswers'] as int,
    startedAt: DateTime.parse(json['startedAt'] as String),
  );
}
