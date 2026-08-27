import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/flashcard.dart';
import '../utils/date_utils.dart' as du;
import '../utils/logger.dart';

/// Kết quả một lượt nạp từ vựng.
class ImportResult {
  /// Các thẻ mới, đã sẵn sàng ghi xuống kho.
  final List<Flashcard> newCards;

  /// Số mục bị bỏ qua vì trùng từ với thẻ đã có hoặc trùng ngay trong file.
  final int duplicateCount;

  /// Mô tả các mục hỏng, mỗi phần tử một dòng.
  ///
  /// Cố ý gom lại rồi trả về thay vì ném lỗi ngay ở mục hỏng đầu tiên: một từ
  /// soạn sai không nên chặn cả bộ 3500 từ. Nhưng cũng không im lặng bỏ qua —
  /// người dùng phải thấy được mục nào hỏng và hỏng vì sao.
  final List<String> errors;

  const ImportResult({
    required this.newCards,
    required this.duplicateCount,
    required this.errors,
  });

  int get importedCount => newCards.length;
}

/// Nạp bộ từ vựng từ file JSON.
///
/// Định dạng nhận vào là một mảng các đối tượng theo đúng cấu trúc
/// [Flashcard.toJson]. Các trường quản trị (`id`, `boxNumber`, `nextReviewDate`,
/// `isActive`...) đều có thể bỏ trống — file từ vựng do người soạn tay thường
/// chỉ có 5 trường nội dung, phần còn lại sẽ được điền giá trị mặc định.
class VocabularyImporter {
  final Logger _log = const Logger('VocabularyImporter');
  final Uuid _uuid;

  VocabularyImporter({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  /// Nạp từ chuỗi JSON thô.
  ///
  /// [existingCards] là kho thẻ hiện có, dùng để loại trùng. Việc so trùng dựa
  /// trên trường `word`, không phân biệt hoa thường và bỏ qua khoảng trắng thừa
  /// hai đầu — vì "Apple", "apple" và " apple " là cùng một từ.
  ImportResult importFromJsonString(
    String rawJson,
    List<Flashcard> existingCards,
  ) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException catch (error) {
      _log.error('File không phải JSON hợp lệ', error);
      throw FormatException('File không phải JSON hợp lệ: ${error.message}');
    }

    if (decoded is! List) {
      throw const FormatException('File phải chứa một mảng các thẻ từ vựng');
    }

    return importFromMaps(decoded, existingCards);
  }

  /// Nạp từ danh sách map đã giải mã sẵn.
  ImportResult importFromMaps(
    List<dynamic> entries,
    List<Flashcard> existingCards,
  ) {
    // Tập từ đã có, chuẩn hoá sẵn để so sánh cho nhanh.
    final seenWords = <String>{
      for (final card in existingCards) _normalizeWord(card.word),
    };

    final newCards = <Flashcard>[];
    final errors = <String>[];
    var duplicateCount = 0;
    final now = DateTime.now();
    final today = du.DateUtils.startOfDay(now);

    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      if (entry is! Map) {
        errors.add('Mục thứ ${index + 1}: không phải một đối tượng JSON');
        continue;
      }

      final json = Map<String, dynamic>.from(entry);

      // Chưa có id thì sinh mới. Việc này phải làm TRƯỚC khi dựng thẻ, vì mã
      // thẻ còn quyết định nhóm Thứ Bảy hay Chủ Nhật ở Hộp 4.
      json.putIfAbsent('id', () => _uuid.v4());
      json.putIfAbsent('createdAt', () => now.toIso8601String());
      json.putIfAbsent('nextReviewDate', () => today.toIso8601String());

      try {
        final card = Flashcard.fromJson(json);
        final normalized = _normalizeWord(card.word);

        // Chặn cả trùng với kho cũ lẫn trùng trong chính file đang nạp.
        if (seenWords.contains(normalized)) {
          duplicateCount++;
          continue;
        }

        seenWords.add(normalized);
        newCards.add(card);
      } on FormatException catch (error) {
        errors.add('Mục thứ ${index + 1}: ${error.message}');
      }
    }

    _log.info(
      'Nạp từ vựng: ${newCards.length} thẻ mới, '
      '$duplicateCount trùng, ${errors.length} lỗi',
    );

    return ImportResult(
      newCards: newCards,
      duplicateCount: duplicateCount,
      errors: errors,
    );
  }

  /// Đưa từ về dạng chuẩn để so trùng.
  static String _normalizeWord(String word) => word.trim().toLowerCase();
}
