import 'package:hive_ce/hive.dart';

import '../models/flashcard.dart';
import '../utils/date_utils.dart' as du;
import '../utils/logger.dart';
import 'card_repository.dart';

/// Bản cài đặt [CardRepository] dùng Hive CE.
///
/// Trên nền web, Hive CE lưu xuống IndexedDB của trình duyệt, nên toàn bộ dữ
/// liệu nằm trên máy người học và đọc được khi không có mạng.
class HiveCardRepository implements CardRepository {
  static const String boxName = 'flashcards';

  final Logger _log = const Logger('HiveCardRepository');
  Box<Flashcard>? _box;

  /// Kho đã mở. Gọi khi chưa [init] thì ném lỗi ngay thay vì tự mở ngầm — mở
  /// ngầm sẽ giấu mất lỗi thiếu khởi tạo cho tới lúc chạy thật.
  Box<Flashcard> get _requireBox {
    final box = _box;
    if (box == null) {
      throw const RepositoryException(
        'Kho thẻ chưa được khởi tạo, phải gọi init() trước',
      );
    }
    return box;
  }

  @override
  Future<void> init() async {
    if (_box != null) return;
    try {
      _box = await Hive.openBox<Flashcard>(boxName);
      _log.info('Đã mở kho thẻ, hiện có ${_box!.length} thẻ');
    } catch (error, stackTrace) {
      _log.error('Không mở được kho thẻ', error, stackTrace);
      throw RepositoryException('Không mở được kho thẻ', error);
    }
  }

  @override
  Future<List<Flashcard>> getAll() async => _requireBox.values.toList();

  @override
  Future<Flashcard?> getById(String id) async => _requireBox.get(id);

  @override
  Future<List<Flashcard>> getDueCards(DateTime day) async {
    // Đến hạn nghĩa là mốc ôn rơi vào bất kỳ lúc nào từ đầu thời gian cho tới
    // hết ngày đang xét — thẻ quá hạn từ hôm trước cũng phải được gom vào.
    final cutoff = du.DateUtils.endOfDay(day);
    return _requireBox.values
        .where((card) => card.isActive && !card.nextReviewDate.isAfter(cutoff))
        .toList();
  }

  @override
  Future<List<Flashcard>> getInactiveCards() async =>
      _requireBox.values.where((card) => !card.isActive).toList();

  @override
  Future<Map<int, int>> countByBox() async {
    // Dựng sẵn đủ 5 khoá để phía giao diện luôn có số cho mọi hộp.
    final counts = <int, int>{for (var box = 1; box <= 5; box++) box: 0};
    for (final card in _requireBox.values) {
      if (!card.isActive) continue;
      counts.update(card.boxNumber, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  @override
  Future<void> save(Flashcard card) async {
    try {
      // Dùng chính id làm khoá để ghi đè đúng thẻ cũ thay vì tạo bản trùng.
      await _requireBox.put(card.id, card);
    } catch (error, stackTrace) {
      _log.error('Không ghi được thẻ ${card.id}', error, stackTrace);
      throw RepositoryException('Không ghi được thẻ ${card.id}', error);
    }
  }

  @override
  Future<void> saveAll(List<Flashcard> cards) async {
    if (cards.isEmpty) return;
    try {
      await _requireBox.putAll({for (final card in cards) card.id: card});
      _log.info('Đã ghi ${cards.length} thẻ');
    } catch (error, stackTrace) {
      _log.error('Không ghi được lô ${cards.length} thẻ', error, stackTrace);
      throw RepositoryException('Không ghi được lô thẻ', error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _requireBox.delete(id);
    } catch (error, stackTrace) {
      _log.error('Không xoá được thẻ $id', error, stackTrace);
      throw RepositoryException('Không xoá được thẻ $id', error);
    }
  }

  @override
  Future<void> clear() async {
    try {
      final removed = await _requireBox.clear();
      _log.warning('Đã xoá sạch kho thẻ ($removed thẻ)');
    } catch (error, stackTrace) {
      _log.error('Không xoá được kho thẻ', error, stackTrace);
      throw RepositoryException('Không xoá được kho thẻ', error);
    }
  }
}
