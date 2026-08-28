import 'package:flutter/material.dart';

/// Giới hạn bề ngang nội dung và căn giữa.
///
/// Ứng dụng nhắm vào điện thoại, nhưng chạy trên trình duyệt nên vẫn có thể bị
/// mở ở cửa sổ rất rộng. Không giới hạn thì thẻ bị kéo dài ra, chữ chạy hết
/// chiều ngang màn hình và mất hẳn cảm giác "một thẻ trên tay". Con số 520 xấp
/// xỉ bề ngang một máy tính bảng cỡ nhỏ — đủ rộng để đọc thoải mái, đủ hẹp để
/// bố cục vẫn giống trên điện thoại.
class ContentWidthLimit extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ContentWidthLimit({
    super.key,
    required this.child,
    this.maxWidth = 520,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
