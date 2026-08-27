import 'package:hive/hive.dart';

part 'test_card.g.dart';

/// Thẻ thử nghiệm — dùng để kiểm tra build_runner
/// trên đường dẫn có dấu tiếng Việt và dấu cách.
@HiveType(typeId: 0)
class TestCard extends HiveObject {
  /// Mặt trước (tiếng Anh)
  @HiveField(0)
  String front;

  /// Mặt sau (nghĩa tiếng Việt)
  @HiveField(1)
  String back;

  /// Hộp Leitner hiện tại (1..5)
  @HiveField(2)
  int boxLevel;

  /// Lần ôn kế tiếp
  @HiveField(3)
  DateTime nextReview;

  TestCard({
    required this.front,
    required this.back,
    this.boxLevel = 1,
    required this.nextReview,
  });
}
