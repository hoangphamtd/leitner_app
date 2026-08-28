import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/flashcard.dart';
import '../utils/logger.dart';

/// Hàm tải một ảnh về máy. Tách ra thành tham số để test không phải chạm mạng.
typedef TaiMotAnh = Future<void> Function(Uri url);

/// Quản lý ảnh minh hoạ của thẻ.
///
/// Vì sao ảnh KHÔNG đóng gói cùng app: bộ từ vựng đầy đủ có 3500 thẻ. Ảnh nét
/// phẳng cỡ 512 điểm ảnh, định dạng WebP, mỗi ảnh khoảng 30 KB — cộng lại
/// khoảng 105 MB. Nhồi chừng đó vào gói cài đặt thì lần mở đầu tiên phải tải
/// hết mới dùng được, và nhiều khả năng vượt hạn mức lưu trữ của Safari trên
/// iPhone. Vì vậy ảnh nằm ngoài gói, tải dần theo nhu cầu.
///
/// Quy tắc: CHỈ tải ảnh của thẻ đã kích hoạt. Người học thường chỉ kích hoạt
/// vài chục tới vài trăm thẻ, nên thực tế chỉ tải vài MB chứ không phải 105 MB.
///
/// Thiếu ảnh KHÔNG được cản việc học: thẻ chưa có ảnh vẫn hiện đủ từ, phiên âm,
/// nghĩa và câu ví dụ, chỉ là chỗ dành cho ảnh để trống.
class IllustrationService extends ChangeNotifier {
  /// Gốc để ghép đường dẫn ảnh tương đối.
  ///
  /// Trên web, `Uri.base` là địa chỉ trang hiện tại, nên `anh/apple.webp` sẽ ra
  /// đúng `<địa chỉ app>/anh/apple.webp`. Cho phép truyền vào để test cố định
  /// được kết quả.
  final Uri base;

  /// Số ảnh tải cùng lúc.
  ///
  /// Ba là con số cố ý thấp: mục tiêu là ảnh về dần trong nền mà không giành
  /// băng thông với thao tác học. Tải ồ ạt trên mạng di động yếu sẽ làm chính
  /// việc học giật.
  final int soLuongSongSong;

  final TaiMotAnh _tai;
  final Logger _log = const Logger('IllustrationService');

  IllustrationService({Uri? base, TaiMotAnh? tai, this.soLuongSongSong = 3})
    : base = base ?? Uri.base,
      _tai = tai ?? _taiBangNetworkImage;

  /// Những ảnh đã tải xong trong phiên này, để không tải lại.
  final Set<String> _daXong = <String>{};

  /// Những ảnh đã thử mà hỏng, để không thử đi thử lại mãi.
  final Set<String> _daHong = <String>{};

  int _tong = 0;
  int _daTai = 0;
  bool _dangChay = false;

  /// Tổng số ảnh cần có cho các thẻ đang kích hoạt.
  int get tong => _tong;

  /// Số ảnh đã tải xong.
  int get daTai => _daTai;

  /// Số ảnh thử tải mà không được.
  int get soHong => _daHong.length;

  /// Đang tải dở hay không.
  bool get dangTai => _dangChay;

  /// Còn bao nhiêu ảnh chưa về.
  int get conLai => _tong - _daTai;

  /// Địa chỉ ảnh của một thẻ. Null nghĩa là thẻ này không có ảnh.
  ///
  /// Chấp nhận cả đường dẫn tương đối (`anh/apple.webp`) lẫn địa chỉ đầy đủ.
  Uri? urlCho(Flashcard card) {
    final duongDan = card.imagePath?.trim();
    if (duongDan == null || duongDan.isEmpty) return null;
    final u = Uri.tryParse(duongDan);
    if (u == null) return null;
    return u.hasScheme ? u : base.resolve(duongDan);
  }

  /// Ảnh của thẻ này đã nằm sẵn trên máy chưa.
  ///
  /// Chỉ biết chắc trong phạm vi phiên hiện tại. Ảnh của phiên trước vẫn nằm
  /// trong kho của service worker và sẽ hiện bình thường kể cả khi mất mạng,
  /// nhưng phía Dart không hỏi được kho đó nên ở đây trả về false.
  bool daCoTrenMay(Flashcard card) {
    final url = urlCho(card);
    return url != null && _daXong.contains(url.toString());
  }

  /// Tải ảnh cho những thẻ ĐÃ KÍCH HOẠT.
  ///
  /// Thẻ chưa kích hoạt bị bỏ qua có chủ đích — đó chính là cách giữ cho lượng
  /// tải xuống nhỏ. Gọi lại nhiều lần vô hại: ảnh đã xong sẽ không tải lại.
  Future<void> dongBo(Iterable<Flashcard> the) async {
    if (_dangChay) return;

    final canTai = <Uri>[];
    var tongCoAnh = 0;
    for (final card in the) {
      if (!card.isActive) continue;
      final url = urlCho(card);
      if (url == null) continue;
      tongCoAnh++;
      final khoa = url.toString();
      if (_daXong.contains(khoa) || _daHong.contains(khoa)) continue;
      canTai.add(url);
    }

    _tong = tongCoAnh;
    _daTai = tongCoAnh - canTai.length;
    if (canTai.isEmpty) {
      notifyListeners();
      return;
    }

    _dangChay = true;
    notifyListeners();

    try {
      // Chia thành từng đợt nhỏ thay vì bắn hết một lượt. Tải song song không
      // giới hạn sẽ chiếm hết kết nối và làm chính việc học giật.
      for (var i = 0; i < canTai.length; i += soLuongSongSong) {
        final dot = canTai.skip(i).take(soLuongSongSong);
        await Future.wait(dot.map(_taiMot));
        notifyListeners();
      }
    } finally {
      _dangChay = false;
      notifyListeners();
    }
  }

  Future<void> _taiMot(Uri url) async {
    final khoa = url.toString();
    try {
      await _tai(url);
      _daXong.add(khoa);
      _daTai++;
    } catch (error) {
      // Ảnh hỏng hay thiếu file KHÔNG được làm gì hơn ngoài việc bị bỏ qua.
      // Thẻ vẫn học được bình thường, chỉ là không có hình.
      _daHong.add(khoa);
      _log.info('Không tải được ảnh $url: $error');
    }
  }

  /// Quên hết những gì đã biết, để thử lại từ đầu.
  void datLai() {
    _daXong.clear();
    _daHong.clear();
    _tong = 0;
    _daTai = 0;
    notifyListeners();
  }
}

/// Bản tải thật: nhờ chính Flutter nạp ảnh.
///
/// Cách này gọn hơn tự viết HTTP và có thêm hai cái lợi: ảnh vào luôn bộ nhớ
/// đệm ảnh của Flutter nên lúc hiện ra không phải giải mã lại, và trên web thì
/// yêu cầu đi qua service worker nên nó cache lại được — đó chính là thứ khiến
/// ảnh đã tải vẫn hiện khi bật chế độ máy bay.
Future<void> _taiBangNetworkImage(Uri url) {
  final hoanTat = Completer<void>();
  final anh = NetworkImage(url.toString());
  final luong = anh.resolve(ImageConfiguration.empty);
  late final ImageStreamListener nguoiNghe;
  nguoiNghe = ImageStreamListener(
    (image, synchronousCall) {
      luong.removeListener(nguoiNghe);
      if (!hoanTat.isCompleted) hoanTat.complete();
    },
    onError: (error, stackTrace) {
      luong.removeListener(nguoiNghe);
      if (!hoanTat.isCompleted) hoanTat.completeError(error);
    },
  );
  luong.addListener(nguoiNghe);
  return hoanTat.future;
}
