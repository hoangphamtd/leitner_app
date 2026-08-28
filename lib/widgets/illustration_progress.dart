import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/illustration_service.dart';

/// Dải mảnh cho biết ảnh minh hoạ đang được tải về.
///
/// Vì sao cần: ảnh không nằm trong gói cài đặt mà tải dần theo nhu cầu, nên có
/// lúc thẻ hiện ra mà chỗ ảnh còn trống. Không nói gì thì người dùng tưởng app
/// hỏng. Dải này chỉ hiện trong lúc còn đang tải, xong là biến mất.
class IllustrationProgress extends StatelessWidget {
  const IllustrationProgress({super.key});

  @override
  Widget build(BuildContext context) {
    final anh = context.watch<IllustrationService?>();
    if (anh == null || !anh.dangTai || anh.tong == 0) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: anh.tong == 0 ? null : anh.daTai / anh.tong,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Đang tải ảnh minh hoạ ${anh.daTai}/${anh.tong}',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dòng trạng thái ảnh minh hoạ, đặt ở màn hình Cài đặt.
///
/// Khác dải trên ở chỗ nó hiện THƯỜNG XUYÊN, kể cả khi đã tải xong — để người
/// dùng chủ động biết máy mình đang giữ bao nhiêu ảnh.
class IllustrationStatusLine extends StatelessWidget {
  const IllustrationStatusLine({super.key});

  @override
  Widget build(BuildContext context) {
    final anh = context.watch<IllustrationService?>();
    if (anh == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final String noiDung;
    if (anh.tong == 0) {
      noiDung = 'Chưa có thẻ nào kèm ảnh minh hoạ';
    } else if (anh.dangTai) {
      noiDung = 'Đang tải ${anh.daTai}/${anh.tong} ảnh';
    } else if (anh.soHong > 0) {
      noiDung =
          'Đã tải ${anh.daTai}/${anh.tong} ảnh · ${anh.soHong} ảnh chưa tải được';
    } else {
      noiDung = 'Đã tải đủ ${anh.daTai} ảnh, xem được cả khi mất mạng';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.image_outlined, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              noiDung,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
