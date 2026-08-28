import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Thẻ lật hai mặt.
///
/// Hiệu ứng là một phép quay quanh trục dọc. Điểm dễ sai nhất khi tự dựng: đến
/// giữa chừng phép quay thì mặt sau đang bị nhìn từ phía sau lưng nên chữ sẽ
/// hiện ngược. Vì vậy mặt sau được quay bù thêm nửa vòng, và việc đổi mặt chỉ
/// diễn ra đúng lúc thẻ nằm nghiêng 90 độ — khi đó bề mặt gần như vô hình nên
/// người xem không thấy cú nhảy.
class FlipCard extends StatefulWidget {
  final Widget front;
  final Widget back;

  /// true thì hiện mặt sau.
  final bool showBack;

  /// Gọi khi người dùng chạm vào thẻ.
  final VoidCallback? onTap;

  final Duration duration;

  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.showBack,
    this.onTap,
    this.duration = const Duration(milliseconds: 420),
  });

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.showBack ? 1 : 0,
  );

  @override
  void didUpdateWidget(FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showBack != oldWidget.showBack) {
      if (widget.showBack) {
        _controller.forward();
      } else {
        // Chuyển sang thẻ mới thì lật úp lại ngay lập tức, không diễn hoạt —
        // nếu diễn hoạt thì người học sẽ kịp thấy đáp án của thẻ vừa xong.
        _controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * math.pi;
          // Qua mốc nửa vòng thì phần đang hướng về người xem là mặt sau.
          final isBackVisible = _controller.value > 0.5;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              // Chút phối cảnh cho cú lật có chiều sâu, không bẹt như tờ giấy.
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: isBackVisible
                // Quay bù nửa vòng để nội dung mặt sau không bị soi gương.
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: widget.back,
                  )
                : widget.front,
          );
        },
      ),
    );
  }
}
