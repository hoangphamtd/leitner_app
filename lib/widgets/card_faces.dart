import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/flashcard.dart';
import '../services/illustration_service.dart';
import 'highlighted_sentence.dart';

/// Khung chung của cả hai mặt thẻ, để mặt trước và mặt sau có cùng kích thước
/// và cùng độ bo góc — nếu lệch thì cú lật sẽ thấy rõ chỗ giật.
class _CardShell extends StatelessWidget {
  final Widget child;
  final Color? background;

  const _CardShell({required this.child, this.background});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Nút loa phát âm.
///
/// Nút chỉ gọi callback được truyền vào chứ không tự biết gì về `flutter_tts` —
/// việc phát tiếng nằm trọn trong `PronunciationService`, đúng yêu cầu Phần 5.
/// Nhờ vậy đổi nguồn tiếng sang file mp3 thu sẵn sẽ không phải sửa widget này.
class SpeakerButton extends StatelessWidget {
  /// Nhãn cho trình đọc màn hình.
  final String semanticLabel;

  final VoidCallback? onPressed;

  const SpeakerButton({super.key, required this.semanticLabel, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: IconButton(
        onPressed: onPressed,
        tooltip: semanticLabel,
        icon: const Icon(Icons.volume_up_rounded),
        iconSize: 28,
        style: IconButton.styleFrom(
          backgroundColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
        ),
      ),
    );
  }
}

/// Mặt trước của thẻ: từ vựng, ảnh minh hoạ, phiên âm.
class CardFront extends StatelessWidget {
  final Flashcard card;

  /// Gọi khi người học bấm nút loa. Null thì nút bị vô hiệu hoá.
  final VoidCallback? onSpeakWord;

  const CardFront({super.key, required this.card, this.onSpeakWord});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _CardShell(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            card.word,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              letterSpacing: 0.5,
            ),
          ),
          // Ảnh chiếm khoảng 40% chiều cao thẻ. Không có ảnh thì để khoảng
          // trống nhã nhặn, tuyệt đối không hiện biểu tượng lỗi.
          Expanded(flex: 4, child: _CardImage(card: card)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  card.phonetic,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SpeakerButton(
                semanticLabel: 'Đọc từ ${card.word}',
                onPressed: onSpeakWord,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Vùng ảnh minh hoạ.
///
/// Ảnh KHÔNG nằm trong gói cài đặt mà tải về theo nhu cầu — xem lý do dài trong
/// `IllustrationService`. Vì vậy ở đây phải chịu được cả ba trạng thái: chưa
/// có ảnh, đang tải, và tải hỏng. Cả ba đều phải để thẻ học được bình thường.
class _CardImage extends StatelessWidget {
  final Flashcard card;

  const _CardImage({required this.card});

  @override
  Widget build(BuildContext context) {
    // Đọc dịch vụ nếu có. Không có cũng không sao: các bài test dựng riêng lẻ
    // một mặt thẻ sẽ không phải dựng cả cây provider chỉ để xem cái ảnh.
    final anh = context.read<IllustrationService?>();
    final url = anh?.urlCho(card);

    if (url == null) {
      // Khoảng trống có chủ ý: giữ đúng bố cục để thẻ có ảnh và thẻ không ảnh
      // không nhảy kích thước khi chuyển qua lại.
      return const SizedBox.expand();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url.toString(),
        fit: BoxFit.contain,
        // Chỉ báo trong lúc ảnh đang về. Cố ý nhỏ và nhạt: ảnh là thứ phụ trợ,
        // không được kéo mắt khỏi từ đang học.
        loadingBuilder: (context, child, tienDo) {
          if (tienDo == null) return child;
          return Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: tienDo.expectedTotalBytes == null
                    ? null
                    : tienDo.cumulativeBytesLoaded / tienDo.expectedTotalBytes!,
              ),
            ),
          );
        },
        // Ảnh hỏng, thiếu file, hay đang mất mạng mà ảnh chưa từng tải về: lặng
        // lẽ trả về khoảng trống. Tuyệt đối không hiện biểu tượng lỗi — thiếu
        // ảnh là chuyện bình thường theo thiết kế, không phải sự cố.
        errorBuilder: (context, error, stackTrace) => const SizedBox.expand(),
      ),
    );
  }
}

/// Mặt sau của thẻ: nghĩa tiếng Việt và câu ví dụ.
class CardBack extends StatelessWidget {
  final Flashcard card;

  /// Gọi khi người học bấm nút loa của câu ví dụ.
  final VoidCallback? onSpeakSentence;

  const CardBack({super.key, required this.card, this.onSpeakSentence});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _CardShell(
      background: scheme.secondaryContainer,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            card.meaning,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: scheme.onSecondaryContainer,
            ),
          ),
          Divider(color: scheme.onSecondaryContainer.withValues(alpha: 0.2)),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  HighlightedSentence(
                    sentence: card.exampleSentence,
                    word: card.word,
                    baseStyle: TextStyle(
                      fontSize: 17,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SpeakerButton(
                    semanticLabel: 'Đọc câu ví dụ',
                    onPressed: onSpeakSentence,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
