import 'package:hive_ce/hive.dart';

part 'flashcard.g.dart';

/// Một thẻ từ vựng trong hệ thống Leitner 5 hộp.
///
/// Đây là đối tượng dữ liệu thuần: nó KHÔNG tự tính lịch ôn và KHÔNG tự ghi
/// xuống ổ đĩa. Toàn bộ thuật toán nằm ở `LeitnerService`, việc lưu trữ nằm ở
/// `CardRepository`. Tách như vậy để sau này đổi cơ chế lưu trữ hoặc cắm thêm
/// đồng bộ máy chủ mà không phải sửa model.
@HiveType(typeId: 0)
class Flashcard {
  /// Mã định danh duy nhất (UUID v4).
  @HiveField(0)
  final String id;

  /// Từ vựng tiếng Anh.
  @HiveField(1)
  final String word;

  /// Phiên âm IPA, luôn nằm trong cặp dấu gạch chéo, ví dụ `/ˈæpəl/`.
  @HiveField(2)
  final String phonetic;

  /// Nghĩa tiếng Việt.
  @HiveField(3)
  final String meaning;

  /// Câu ví dụ tình huống đời thường, có chứa [word].
  @HiveField(4)
  final String exampleSentence;

  /// Đường dẫn ảnh minh hoạ cục bộ. Null nghĩa là thẻ chưa có ảnh.
  @HiveField(5)
  final String? imagePath;

  /// Đường dẫn file mp3 cục bộ. Giai đoạn này LUÔN null — khi null thì phát âm
  /// sẽ do TTS đảm nhiệm. Trường này để dành cho giai đoạn thu âm sau.
  @HiveField(6)
  final String? audioPath;

  /// Hộp Leitner hiện tại, từ 1 đến 5.
  @HiveField(7)
  final int boxNumber;

  /// Mốc đến hạn ôn. Luôn được chuẩn hoá về 00:00 giờ địa phương.
  @HiveField(8)
  final DateTime nextReviewDate;

  /// false = thẻ còn nằm trong thư viện, chưa được đưa vào vòng học.
  @HiveField(9)
  final bool isActive;

  @HiveField(10)
  final DateTime createdAt;

  /// Bắt buộc cập nhật ở MỌI lần sửa thẻ. Trường này là mốc so sánh cho việc
  /// đồng bộ máy chủ trong tương lai, nên sai một lần là hỏng cả vòng đồng bộ.
  @HiveField(11)
  final DateTime updatedAt;

  /// Tổng số lượt người học đã trả lời thẻ này (đúng lẫn sai).
  @HiveField(12)
  final int reviewCount;

  /// Số lượt trả lời sai.
  @HiveField(13)
  final int lapseCount;

  const Flashcard({
    required this.id,
    required this.word,
    required this.phonetic,
    required this.meaning,
    required this.exampleSentence,
    this.imagePath,
    this.audioPath,
    required this.boxNumber,
    required this.nextReviewDate,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.reviewCount = 0,
    this.lapseCount = 0,
  });

  /// Tạo bản sao đã sửa vài trường. Model là bất biến (immutable) nên mọi thay
  /// đổi đều đi qua đây — nhờ vậy không có chỗ nào lỡ tay sửa thẻ mà quên
  /// [updatedAt].
  ///
  /// Hai trường nullable [imagePath] và [audioPath] dùng cờ `clear...` riêng,
  /// vì nếu chỉ dựa vào `null` thì không phân biệt được "giữ nguyên" với
  /// "xoá đi".
  Flashcard copyWith({
    String? word,
    String? phonetic,
    String? meaning,
    String? exampleSentence,
    String? imagePath,
    bool clearImagePath = false,
    String? audioPath,
    bool clearAudioPath = false,
    int? boxNumber,
    DateTime? nextReviewDate,
    bool? isActive,
    DateTime? updatedAt,
    int? reviewCount,
    int? lapseCount,
  }) {
    return Flashcard(
      id: id,
      word: word ?? this.word,
      phonetic: phonetic ?? this.phonetic,
      meaning: meaning ?? this.meaning,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      audioPath: clearAudioPath ? null : (audioPath ?? this.audioPath),
      boxNumber: boxNumber ?? this.boxNumber,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewCount: reviewCount ?? this.reviewCount,
      lapseCount: lapseCount ?? this.lapseCount,
    );
  }

  /// Chuyển sang JSON để xuất sao lưu và để nạp bộ từ vựng từ file.
  Map<String, dynamic> toJson() => {
    'id': id,
    'word': word,
    'phonetic': phonetic,
    'meaning': meaning,
    'exampleSentence': exampleSentence,
    'imagePath': imagePath,
    'audioPath': audioPath,
    'boxNumber': boxNumber,
    'nextReviewDate': nextReviewDate.toIso8601String(),
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'reviewCount': reviewCount,
    'lapseCount': lapseCount,
  };

  /// Dựng thẻ từ JSON.
  ///
  /// Cố ý khoan dung với các trường quản trị (hộp, ngày, số đếm) vì file từ
  /// vựng do người soạn tay thường chỉ có 5 trường nội dung. Ngược lại, thiếu
  /// trường nội dung bắt buộc thì ném lỗi ngay chứ không âm thầm điền chuỗi
  /// rỗng — thà báo lỗi còn hơn nạp vào một thẻ hỏng.
  factory Flashcard.fromJson(Map<String, dynamic> json) {
    String requireText(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Thẻ thiếu trường bắt buộc "$key"', json);
      }
      return value;
    }

    DateTime? parseDate(String key) {
      final raw = json[key];
      if (raw == null) return null;
      if (raw is! String) {
        throw FormatException('Trường "$key" phải là chuỗi ISO 8601', json);
      }
      return DateTime.parse(raw);
    }

    final now = DateTime.now();
    final createdAt = parseDate('createdAt') ?? now;

    return Flashcard(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? json['id'] as String
          : throw FormatException('Thẻ thiếu trường bắt buộc "id"', json),
      word: requireText('word'),
      phonetic: requireText('phonetic'),
      meaning: requireText('meaning'),
      exampleSentence: requireText('exampleSentence'),
      imagePath: json['imagePath'] as String?,
      audioPath: json['audioPath'] as String?,
      boxNumber: json['boxNumber'] as int? ?? 1,
      nextReviewDate: parseDate('nextReviewDate') ?? createdAt,
      isActive: json['isActive'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt: parseDate('updatedAt') ?? createdAt,
      reviewCount: json['reviewCount'] as int? ?? 0,
      lapseCount: json['lapseCount'] as int? ?? 0,
    );
  }

  @override
  String toString() => 'Flashcard($id, "$word", hộp $boxNumber)';
}
