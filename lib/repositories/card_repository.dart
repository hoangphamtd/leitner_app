import '../models/flashcard.dart';

/// Lỗi phát sinh ở tầng lưu trữ.
///
/// Mọi bản cài đặt repository phải bọc lỗi gốc của thư viện lưu trữ vào đây,
/// để tầng trên không phải biết bên dưới là Hive, IndexedDB hay máy chủ.
class RepositoryException implements Exception {
  final String message;
  final Object? cause;

  const RepositoryException(this.message, [this.cause]);

  @override
  String toString() =>
      'RepositoryException: $message${cause == null ? '' : ' ($cause)'}';
}

/// Cổng duy nhất để đọc và ghi thẻ từ vựng.
///
/// Đây là interface trừu tượng, cố ý không nhắc gì tới Hive hay IndexedDB. Giao
/// diện chỉ được phép gọi qua đây, không bao giờ chạm thẳng vào thư viện lưu
/// trữ. Nhờ vậy sau này muốn cắm thêm đồng bộ máy chủ thì chỉ cần viết một bản
/// cài đặt mới, không phải sửa một dòng nào ở tầng trên.
abstract class CardRepository {
  /// Mở kết nối tới kho dữ liệu. Phải gọi trước mọi thao tác khác.
  Future<void> init();

  /// Toàn bộ thẻ, kể cả thẻ chưa kích hoạt.
  Future<List<Flashcard>> getAll();

  /// Lấy một thẻ theo mã. Trả về null nếu không có.
  Future<Flashcard?> getById(String id);

  /// Các thẻ đã kích hoạt và đến hạn ôn tính đến hết ngày [day].
  ///
  /// Repository chỉ lọc thô theo điều kiện dữ liệu. Việc sắp xếp hàng đợi là
  /// nghiệp vụ, thuộc về `LeitnerService`, không làm ở đây.
  Future<List<Flashcard>> getDueCards(DateTime day);

  /// Các thẻ chưa kích hoạt, tức còn nằm trong thư viện.
  Future<List<Flashcard>> getInactiveCards();

  /// Đếm số thẻ trong từng hộp, chỉ tính thẻ đã kích hoạt.
  ///
  /// Trả về map đủ 5 khoá từ 1 đến 5; hộp rỗng thì giá trị bằng 0, để phía giao
  /// diện không phải kiểm tra null.
  Future<Map<int, int>> countByBox();

  /// Thêm mới hoặc ghi đè một thẻ.
  Future<void> save(Flashcard card);

  /// Ghi nhiều thẻ trong một lượt. Dùng khi nạp bộ từ vựng lớn.
  Future<void> saveAll(List<Flashcard> cards);

  Future<void> delete(String id);

  /// Xoá sạch kho thẻ. Dùng khi người học nhập đè file sao lưu.
  Future<void> clear();
}
