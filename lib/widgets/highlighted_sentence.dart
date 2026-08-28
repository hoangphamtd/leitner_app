import 'package:flutter/material.dart';

/// Câu ví dụ in nghiêng, có bôi đậm từ vựng chính nằm trong câu.
///
/// Việc dò từ phải chịu được các dạng chia đuôi: thẻ dạy `recommend` nhưng câu
/// ví dụ viết `recommended`. Cách xử lý: cắt bớt vài ký tự cuối của từ gốc để
/// lấy phần thân, dò phần thân đó trong câu, rồi mở rộng vệt bôi đậm ra hết các
/// chữ cái liền kề — nhờ vậy `recommended` được tô trọn vẹn chứ không tô nửa vời.
class HighlightedSentence extends StatelessWidget {
  final String sentence;

  /// Từ vựng cần bôi đậm.
  final String word;

  final TextStyle? baseStyle;

  const HighlightedSentence({
    super.key,
    required this.sentence,
    required this.word,
    this.baseStyle,
  });

  /// Số ký tự tối thiểu của phần thân từ, để tránh dò trúng những mảnh quá ngắn.
  static const int _minimumStemLength = 4;

  /// Tìm vệt cần bôi đậm trong câu. Trả về null nếu không tìm thấy.
  ///
  /// Hàm được tách riêng và để ở dạng tĩnh để unit test gọi được trực tiếp.
  static ({int start, int end})? findHighlightRange(
    String sentence,
    String word,
  ) {
    final cleanWord = word.trim();
    if (cleanWord.isEmpty || sentence.isEmpty) return null;

    final haystack = sentence.toLowerCase();

    // Thử từ nguyên vẹn trước, rồi mới cắt dần đuôi. Cắt tối đa 2 ký tự là đủ
    // cho các đuôi thường gặp trong tiếng Anh (-s, -ed, -ing đã được phần mở
    // rộng phía sau lo nốt).
    for (var trim = 0; trim <= 2; trim++) {
      final stem = cleanWord.substring(0, cleanWord.length - trim);
      if (stem.length < _minimumStemLength && trim > 0) break;

      final index = haystack.indexOf(stem.toLowerCase());
      if (index < 0) continue;

      // Mở rộng sang phải qua hết các chữ cái liền kề, để phủ trọn phần đuôi.
      var end = index + stem.length;
      while (end < sentence.length && _isWordCharacter(sentence[end])) {
        end++;
      }
      // Mở rộng sang trái tương tự, phòng khi dò trúng giữa một từ dài hơn.
      var start = index;
      while (start > 0 && _isWordCharacter(sentence[start - 1])) {
        start--;
      }
      return (start: start, end: end);
    }
    return null;
  }

  static bool _isWordCharacter(String character) =>
      RegExp(r"[A-Za-z']").hasMatch(character);

  @override
  Widget build(BuildContext context) {
    final style = (baseStyle ?? Theme.of(context).textTheme.bodyLarge)
        ?.copyWith(fontStyle: FontStyle.italic, height: 1.5);

    final range = findHighlightRange(sentence, word);
    if (range == null) {
      // Không dò được thì hiển thị nguyên câu, tuyệt đối không bôi bừa.
      return Text(sentence, style: style, textAlign: TextAlign.center);
    }

    final emphasis = style?.copyWith(
      fontWeight: FontWeight.w800,
      color: Theme.of(context).colorScheme.primary,
    );

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: sentence.substring(0, range.start)),
          TextSpan(
            text: sentence.substring(range.start, range.end),
            style: emphasis,
          ),
          TextSpan(text: sentence.substring(range.end)),
        ],
      ),
    );
  }
}
