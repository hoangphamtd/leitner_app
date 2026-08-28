import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/flashcard.dart';
import '../providers/deck_provider.dart';
import '../services/diagnostics_service.dart';
import '../utils/date_utils.dart' as du;
import '../utils/web_metrics/web_metrics.dart';

/// Màn hình chẩn đoán hiệu năng.
///
/// Lý do tồn tại: lỗi chậm chỉ xuất hiện trên điện thoại thật, mà trên điện
/// thoại thì không mở được công cụ nhà phát triển để xem console hay đo đạc.
/// Màn hình này để app tự đo trên chính máy người dùng rồi hiện số lên, chữ đủ
/// to để đọc và chụp màn hình gửi đi được.
///
/// Vào được bằng hai đường: nút trong Cài đặt, hoặc mở thẳng địa chỉ kết thúc
/// bằng `#debug`.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  static const WebMetrics _web = WebMetrics();
  final DiagnosticsService _chan = DiagnosticsService.instance;

  /// Kết quả phép đo thao tác, null nghĩa là chưa đo lần nào.
  Map<String, int>? _ketQuaDo;
  bool _dangDo = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chẩn đoán'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Đọc lại số liệu',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _Nhom(
              tieuDe: 'Thời gian khởi động',
              dong: [
                (
                  'Mở trang tới khung hình đầu',
                  _msHoacTrong(_web.firstFrameMs),
                ),
                ('Khởi tạo kho Hive', _msHoacTrong(_chan.hiveInitMs)),
                (
                  'Mồi từ vựng mẫu',
                  _msHoacTrong(_chan.seedMs, khiNull: 'không chạy'),
                ),
                ('Từ main() tới runApp', _msHoacTrong(_chan.bootstrapMs)),
                ('App đã chạy được', '${_web.uptimeMs} ms'),
              ],
            ),
            const SizedBox(height: 16),
            _Nhom(
              tieuDe: 'Máy và bộ vẽ',
              dong: [
                ('Bộ vẽ đang dùng', _web.renderer),
                ('Số lõi CPU', '${_web.hardwareConcurrency}'),
                (
                  'Bộ nhớ máy',
                  _web.deviceMemoryGb > 0
                      ? '${_web.deviceMemoryGb.toStringAsFixed(0)} GB'
                      : 'trình duyệt không cho biết',
                ),
                (
                  'Đã cài vào màn hình chính',
                  _web.isStandalone ? 'rồi' : 'chưa',
                ),
                (
                  'Kích thước màn hình',
                  '${MediaQuery.sizeOf(context).width.round()}'
                      ' x ${MediaQuery.sizeOf(context).height.round()}'
                      ' @ ${MediaQuery.devicePixelRatioOf(context).toStringAsFixed(1)}x',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DoThaoTac(dangDo: _dangDo, ketQua: _ketQuaDo, onDo: _chayPhepDo),
            const SizedBox(height: 16),
            _NhatKyCham(mau: _chan.touches),
            const SizedBox(height: 16),
            _DanhSachLoi(loiJs: _web.jsErrors, loiDart: _chan.dartErrors),
            const SizedBox(height: 16),
            _KhungChu(tieuDe: 'Trình duyệt', noiDung: _web.userAgent),
          ],
        ),
      ),
    );
  }

  String _msHoacTrong(int? value, {String khiNull = 'chưa có'}) =>
      value == null ? khiNull : '$value ms';

  /// Chạy thử đúng chuỗi thao tác mà người dùng than là chậm, và tách ra xem
  /// thời gian rơi vào khâu nào.
  ///
  /// Dùng thẻ giả có tiền tố riêng rồi xoá sạch, để phép đo không đụng tới dữ
  /// liệu học thật.
  Future<void> _chayPhepDo() async {
    setState(() {
      _dangDo = true;
      _ketQuaDo = null;
    });

    final deck = context.read<DeckProvider>();
    final kho = deck.cardRepository;
    final ketQua = <String, int>{};
    final now = DateTime.now();

    try {
      // 1. Đọc toàn bộ kho
      var sw = Stopwatch()..start();
      final tatCa = await kho.getAll();
      sw.stop();
      ketQua['Đọc toàn bộ kho (${tatCa.length} thẻ)'] = sw.elapsedMilliseconds;

      // 2. Ghi gộp 15 thẻ, đúng như lúc kích hoạt từ mới
      final theGia = List.generate(
        15,
        (i) => Flashcard(
          id: '__do_$i',
          word: 'probe$i',
          phonetic: '/p/',
          meaning: 'thẻ đo, sẽ bị xoá ngay',
          exampleSentence: 'This is a probe card used only for measurement.',
          boxNumber: 1,
          nextReviewDate: du.DateUtils.startOfDay(now),
          isActive: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
      sw = Stopwatch()..start();
      await kho.saveAll(theGia);
      sw.stop();
      ketQua['Ghi gộp 15 thẻ'] = sw.elapsedMilliseconds;

      // 3. Đọc lại toàn bộ số liệu tổng quan
      sw = Stopwatch()..start();
      await deck.refresh();
      sw.stop();
      ketQua['Đọc lại số liệu Tổng quan'] = sw.elapsedMilliseconds;

      // 4. Dọn thẻ đo
      sw = Stopwatch()..start();
      for (final the in theGia) {
        await kho.delete(the.id);
      }
      sw.stop();
      ketQua['Xoá lần lượt 15 thẻ'] = sw.elapsedMilliseconds;

      await deck.refresh();
      ketQua['TỔNG'] = ketQua.values.reduce((a, b) => a + b);
    } catch (error) {
      _chan.recordDartError(error);
      ketQua['LỖI'] = -1;
    }

    if (!mounted) return;
    setState(() {
      _dangDo = false;
      _ketQuaDo = ketQua;
    });
  }
}

/// Khung một nhóm số liệu dạng nhãn — giá trị.
class _Nhom extends StatelessWidget {
  final String tieuDe;
  final List<(String, String)> dong;

  const _Nhom({required this.tieuDe, required this.dong});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tieuDe,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          for (final (nhan, giaTri) in dong)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(nhan, style: const TextStyle(fontSize: 15)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      giaTri,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DoThaoTac extends StatelessWidget {
  final bool dangDo;
  final Map<String, int>? ketQua;
  final VoidCallback onDo;

  const _DoThaoTac({
    required this.dangDo,
    required this.ketQua,
    required this.onDo,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đo thao tác',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Chạy thử đúng chuỗi việc của nút "Thêm từ mới", '
            'tách xem thời gian rơi vào khâu nào. Dùng thẻ giả rồi xoá ngay, '
            'không đụng tới dữ liệu học.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: dangDo ? null : onDo,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: dangDo
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Icon(Icons.timer_outlined),
            label: Text(dangDo ? 'Đang đo…' : 'ĐO THAO TÁC'),
          ),
          if (ketQua != null) ...[
            const SizedBox(height: 12),
            for (final e in ketQua!.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.key,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: e.key == 'TỔNG'
                              ? FontWeight.w800
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      e.value < 0 ? 'lỗi' : '${e.value} ms',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: e.value > 500 ? scheme.error : scheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Nhật ký 20 lần chạm gần nhất kèm độ trễ phản hồi.
class _NhatKyCham extends StatelessWidget {
  final List<TouchSample> mau;

  const _NhatKyCham({required this.mau});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '20 lần chạm gần nhất',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Độ trễ là khoảng từ lúc ngón tay chạm tới lúc màn hình vẽ xong. '
            'Dưới 100 ms là mượt, trên 300 ms là thấy khựng, '
            'trên 1000 ms là tưởng nút hỏng.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          if (mau.isEmpty)
            const Text(
              'Chưa ghi được lần chạm nào. Hãy bấm vài nút rồi quay lại đây.',
              style: TextStyle(fontStyle: FontStyle.italic),
            )
          else
            for (final m in mau)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${(m.atMs / 1000).toStringAsFixed(1)}s',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '(${m.x}, ${m.y})',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      '${m.latencyMs} ms',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: m.latencyMs > 300
                            ? scheme.error
                            : (m.latencyMs > 100
                                  ? scheme.tertiary
                                  : scheme.onSurface),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Mọi lỗi bắt được, cả phía JavaScript lẫn phía Dart.
class _DanhSachLoi extends StatelessWidget {
  final List<JsError> loiJs;
  final List<DartErrorSample> loiDart;

  const _DanhSachLoi({required this.loiJs, required this.loiDart});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coLoi = loiJs.isNotEmpty || loiDart.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: coLoi ? scheme.errorContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: coLoi ? scheme.error : scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            coLoi
                ? 'CÓ LỖI: ${loiJs.length + loiDart.length}'
                : 'Không có lỗi nào',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: coLoi ? scheme.onErrorContainer : scheme.primary,
            ),
          ),
          if (coLoi) ...[
            const SizedBox(height: 8),
            for (final e in loiJs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '[JS ${e.luc} ms] ${e.nguon}\n${e.thongDiep}'
                  '${e.chiTiet == null ? '' : '\n${e.chiTiet}'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            for (final e in loiDart)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '[Dart ${e.atMs} ms] ${e.message}',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _KhungChu extends StatelessWidget {
  final String tieuDe;
  final String noiDung;

  const _KhungChu({required this.tieuDe, required this.noiDung});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tieuDe,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(noiDung, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
