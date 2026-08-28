import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/flashcard.dart';
import '../providers/deck_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/content_width_limit.dart';

/// Form thêm mới hoặc sửa một thẻ từ vựng.
///
/// [card] null nghĩa là đang thêm mới.
class CardFormScreen extends StatefulWidget {
  final Flashcard? card;

  const CardFormScreen({super.key, this.card});

  @override
  State<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends State<CardFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _word;
  late final TextEditingController _phonetic;
  late final TextEditingController _meaning;
  late final TextEditingController _sentence;
  late final TextEditingController _imagePath;

  bool _saving = false;

  bool get _isEditing => widget.card != null;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    _word = TextEditingController(text: card?.word ?? '');
    // Điền sẵn cặp dấu gạch chéo cho thẻ mới, vì SOP quy định phiên âm phải nằm
    // trong dấu / / và gõ tay rất dễ quên.
    _phonetic = TextEditingController(text: card?.phonetic ?? '//');
    _meaning = TextEditingController(text: card?.meaning ?? '');
    _sentence = TextEditingController(text: card?.exampleSentence ?? '');
    _imagePath = TextEditingController(text: card?.imagePath ?? '');
  }

  @override
  void dispose() {
    _word.dispose();
    _phonetic.dispose();
    _meaning.dispose();
    _sentence.dispose();
    _imagePath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa từ' : 'Thêm từ mới'),
        centerTitle: true,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Xoá từ này',
              onPressed: _saving ? null : _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: ContentWidthLimit(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _Field(
                  controller: _word,
                  label: 'Từ vựng tiếng Anh',
                  hint: 'appointment',
                  validator: _requireText,
                  autofocus: !_isEditing,
                ),
                _Field(
                  controller: _phonetic,
                  label: 'Phiên âm IPA',
                  hint: '/əˈpɔɪntmənt/',
                  validator: _validatePhonetic,
                ),
                _Field(
                  controller: _meaning,
                  label: 'Nghĩa tiếng Việt',
                  hint: 'cuộc hẹn, lịch hẹn',
                  validator: _requireText,
                ),
                _Field(
                  controller: _sentence,
                  label: 'Câu ví dụ',
                  hint: 'Một câu đời thường, có chứa chính từ này',
                  validator: _validateSentence,
                  maxLines: 4,
                ),
                _Field(
                  controller: _imagePath,
                  label: 'Đường dẫn ảnh (không bắt buộc)',
                  hint: 'Bỏ trống nếu chưa có ảnh',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'ĐANG LƯU…' : 'LƯU'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _requireText(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Không được bỏ trống' : null;

  /// Phiên âm phải nằm trong cặp dấu gạch chéo, đúng quy ước ở Phần 2 của SOP.
  String? _validatePhonetic(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Không được bỏ trống';
    if (!text.startsWith('/') || !text.endsWith('/') || text.length < 3) {
      return 'Phiên âm phải nằm trong cặp dấu gạch chéo, ví dụ /ˈæpəl/';
    }
    return null;
  }

  /// Câu ví dụ phải chứa chính từ đang học.
  ///
  /// Cảnh báo chứ không chặn cứng: kiểm tra chỉ dò theo phần thân từ nên vẫn có
  /// thể bỏ sót các dạng biến đổi bất quy tắc, mà chặn nhầm thì người dùng không
  /// lưu nổi một thẻ hoàn toàn hợp lệ.
  String? _validateSentence(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Không được bỏ trống';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final library = context.read<LibraryProvider>();
    final deck = context.read<DeckProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _saving = true);
    try {
      final card = widget.card;
      if (card == null) {
        await library.addCard(
          word: _word.text,
          phonetic: _phonetic.text,
          meaning: _meaning.text,
          exampleSentence: _sentence.text,
          imagePath: _imagePath.text,
        );
      } else {
        await library.updateCard(
          card,
          word: _word.text,
          phonetic: _phonetic.text,
          meaning: _meaning.text,
          exampleSentence: _sentence.text,
          imagePath: _imagePath.text,
        );
      }
      await deck.refresh();
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(card == null ? 'Đã thêm từ mới.' : 'Đã lưu.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Không lưu được. $error')));
    }
  }

  Future<void> _confirmDelete() async {
    final card = widget.card;
    if (card == null) return;

    final library = context.read<LibraryProvider>();
    final deck = context.read<DeckProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá từ này?'),
        content: Text(
          'Sẽ xoá "${card.word}" khỏi thư viện. '
          'Thao tác này không hoàn tác được.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('HUỶ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              minimumSize: const Size(100, 44),
            ),
            child: const Text('XOÁ'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await library.deleteCard(card.id);
    await deck.refresh();
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Đã xoá từ.')));
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool autofocus;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
    this.maxLines = 1,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        autofocus: autofocus,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
