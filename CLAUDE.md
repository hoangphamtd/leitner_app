# Leitner App — Quy tắc dự án

## Xưng hô và ngôn ngữ

- Gọi người dùng là **"Thầy"**, tự xưng **"em"**. **Không** gọi "anh".
- Trả lời bằng **tiếng Việt**.
- **Chú thích trong code viết bằng tiếng Việt.**

## Đường dẫn — TUYỆT ĐỐI KHÔNG ĐỔI

Dự án đặt tại `D:\projects\leitner_app`.

**Không bao giờ di chuyển dự án vào đường dẫn có dấu tiếng Việt.** Đã kiểm chứng
thực tế (27/08/2026) — dấu tiếng Việt trong đường dẫn gây **hai lỗi độc lập**:

1. **`dart run` / `build_runner` chết ngay** với thông báo:
   `package_config.json did not contain its own root package`
   Chỉ xảy ra khi có **chữ HOA có dấu** (Ự, Á, Ố, Ẩ…). Chữ thường có dấu (ế, ư, ệ) thì không sao.

2. **`flutter build web` chết ở icon tree-shaker:**
   `IconTreeShakerException: Font subsetting failed with exit code -1`
   Công cụ native `font-subset` không đọc được UTF-8 — đường dẫn biến thành `D? ?N C? V?N…`.
   Lỗi này **mọi dấu tiếng Việt đều dính**, kể cả chữ thường. Vá tạm bằng
   `--no-tree-shake-icons`, nhưng cách đúng là giữ dự án ở đường dẫn ASCII.

Cùng bẫy này: COM `WScript.Shell` cũng không tạo nổi file ở đường dẫn tiếng Việt —
phải tạo ở chỗ ASCII rồi chép sang bằng `[System.IO.File]::Copy`.

Có một lối tắt (shortcut `.lnk`) trỏ về đây, đặt tại
`D:\AI AGENT BRICH 2026\DỰ ÁN CỐ VẤN PHONG THỦY APP\App Tiếng Anh\leitner_app.lnk`.
Đó là shortcut thường, **không phải symlink/junction** — cố ý như vậy để Flutter
không đi ngược theo nó vào đường dẫn tiếng Việt.

## Lưu trữ dữ liệu — dùng `hive_ce`

Dùng **`hive_ce`, `hive_ce_flutter`, `hive_ce_generator`**.

**Không dùng `hive` / `hive_generator` gốc.** `hive_generator` 2.0.1 đã bỏ hoang từ 2022,
ghim `analyzer` 6.x (chỉ hiểu Dart 3.4) nên không parse nổi cú pháp Dart 3.13 — báo
`Expected an identifier` ngay trên `main.dart` mặc định, chưa cần code của mình.
`hive_ce` kéo `analyzer` 14.x nên chạy sạch. API `@HiveType` / `@HiveField` giữ nguyên.

## Lệnh build web — BẮT BUỘC `--no-web-resources-cdn`, KHÔNG dùng `--wasm`

Lệnh build đúng của dự án:

```bash
flutter build web --no-web-resources-cdn
```

**`--no-web-resources-cdn` là bắt buộc.** Không có cờ này, Flutter tải CanvasKit và
font Roboto từ `gstatic.com`, tức là app phụ thuộc mạng ở lần chạy đầu và service
worker không cache được (khác miền). Có cờ này thì CanvasKit nằm cùng miền, service
worker cache được, app chạy offline thật.

**Không dùng `--wasm`.** `flutter build web` sẽ in cảnh báo `Wasm dry run failed` —
**bỏ qua**. Nguyên nhân đã truy rõ: `flutter_tts` kéo theo `jni` (Android) và
`objective_c` (iOS), hai gói đó dùng `dart:ffi` mà WasmGC không hỗ trợ. Trên web
chúng không được nạp nên bản build JS chạy bình thường.

## `web/index.html` — hai dòng làm hỏng cả app trên iPhone

**Không khai báo `<meta name="viewport">`.** Engine Flutter **xoá sạch** mọi thẻ
viewport có sẵn rồi tự đặt lại thẻ của nó — xem `_applyViewportMeta` trong
`flutter/lib/ui/src/engine/view_embedder/embedding_strategy/full_page_embedding_strategy.dart`.
Cảnh báo về việc này nằm trong `assert()` nên **bản phát hành hoàn toàn im lặng**.

**`apple-mobile-web-app-status-bar-style` phải là `black`**, đúng như mẫu gốc.
Không dùng `black-translucent`.

Hai dòng đó cộng lại đã làm app **không dùng được trên iPhone** (28/08/2026):
ở chế độ đã cài vào màn hình chính, vùng VẼ và vùng NHẬN CHẠM lệch nhau đúng
bằng chiều cao thanh trạng thái (~47 điểm ảnh). Chạm đúng chỗ nhìn thấy nút thì
trượt; chạm cao hơn 47 điểm mới trúng. Mọi nút, không riêng nút nào.

Triệu chứng đánh lừa rất nặng, ghi lại để lần sau khỏi đi lại đường vòng:

* Mở bằng Safari thì bình thường (lề an toàn khác nên độ lệch nhỏ hoặc bằng 0),
  chỉ chế độ đã cài mới hỏng → dễ tưởng là lỗi hiệu năng của chế độ standalone.
* Nhật ký chạm đo được **0–13 ms**, không lỗi nào → app trông rất mượt.
  `Listener` ở gốc là `HitTestBehavior.translucent` nên nó **ghi nhận cú chạm kể
  cả khi không nút nào nhận được**. Nhật ký đẹp KHÔNG chứng minh nút có ăn.
* "Bấm mãi mới vào được Cài đặt" thực ra là bấm trượt vài lần rồi tình cờ trúng.

`test/web_shell_test.dart` khoá lại cả hai dòng, cộng với máy đo trong
index.html ghi toạ độ thô của trình duyệt. Màn hình Chẩn đoán hiện cột **"lệch"**
— hiệu giữa toạ độ Flutter tính ra và toạ độ trình duyệt báo cho cùng cú chạm.
**Phải bằng 0.** Đây là thứ duy nhất nhìn thấy được lỗi này trên máy thật, vì
test widget chạy trên máy ảo Dart, không có trình duyệt nên không dựng lại được.

## Dải báo cập nhật — đừng báo nhầm ở lần cài đầu

`clients.claim()` trong `sw.js` cũng bắn ra `controllerchange` ngay lần cài đầu
tiên. Không có bảo vệ thì người vừa cài xong đã thấy "Có bản cập nhật", bấm rồi
lại hiện tiếp. Vì vậy `index.html` chụp `navigator.serviceWorker.controller`
**trước khi đăng ký** (`coNguoiPhucVuTuDau`) và chỉ báo bản mới khi nó khác null.

Ngoài ra màn hình **Cài đặt có nút "TẢI LẠI APP"** riêng, độc lập với dải — vì
đã có lần chính nút TẢI LẠI trong dải hỏng, và người dùng kẹt cứng không còn
đường nào ra.

## Service worker — TỰ VIẾT, đừng trông vào Flutter

Từ Flutter 3.2x, service worker do `flutter build web` sinh ra **đã bị khai tử**:
`flutter_service_worker.js` không cache gì cả, nó chỉ tự gỡ đăng ký chính mình.
Đã kiểm chứng thực tế (27/08/2026): với cấu hình mặc định, tắt máy chủ rồi tải lại
trang thì trình duyệt báo **trang lỗi** — 0 service worker, 0 mục cache.

Dự án vì vậy có hai file tự viết, **đừng xoá**:

* `web/sw.js` — service worker thật: nạp sẵn phần lõi lúc cài, còn lại cache theo
  runtime; yêu cầu điều hướng luôn trả về `index.html` từ cache.
* `web/flutter_bootstrap.js` — bản khởi động tuỳ biến, cố ý gọi `_flutter.loader.load()`
  **không tham số** để Flutter không đăng ký service worker của nó (nếu đăng ký, nó
  chiếm mất phạm vi rồi gỡ luôn `sw.js`).

`web/index.html` tự đăng ký `sw.js` sau sự kiện `load`.

### Cơ chế cập nhật — đừng phá hai thứ này

Bản `sw.js` đầu tiên khiến người dùng **kẹt cứng ở bản cũ** qua nhiều lần triển
khai. Hai nguyên nhân cộng hưởng: `CACHE_NAME` là hằng số nên `sw.js` không đổi
nội dung giữa các bản build (trình duyệt coi service worker y hệt, không cài
lại, `activate` không chạy, cache cũ không bị dọn); và mọi tài nguyên đều lấy
cache trước, trong khi `main.dart.js` chứa toàn bộ mã ứng dụng lại có tên cố
định không kèm mã băm.

Hai thứ giữ cho cơ chế cập nhật sống, **tuyệt đối không gỡ**:

1. Bước **"Đóng dấu mã build"** trong `.github/workflows/deploy.yml` — thay
   `__BUILD_VERSION__` bằng mã commit, khiến `sw.js` đổi nội dung mỗi lần build.
2. Nhóm **khung ứng dụng lấy MẠNG TRƯỚC** trong `sw.js` (`index.html`,
   `main.dart.js`, `flutter_bootstrap.js`, `manifest.json`).

Kèm theo: đăng ký service worker với `updateViaCache: 'none'`, gọi `update()` mỗi
lần mở app, và dải "Có bản cập nhật — TẢI LẠI" ở `lib/widgets/update_banner.dart`.

Mã phiên bản hiện ở cuối màn hình Cài đặt để luôn biết máy đang chạy bản nào.

## Ảnh minh hoạ — KHÔNG đóng gói cùng app

Bộ đầy đủ 3500 ảnh WebP 512px, mỗi ảnh khoảng 30 KB, cộng lại **khoảng 105 MB**.
Nạp sẵn chừng đó thì lần mở đầu phải tải hết mới dùng được và nhiều khả năng
vượt hạn mức lưu trữ của Safari trên iPhone. Vì vậy:

* Ảnh nằm ở `web/anh/`, phục vụ tại `<địa chỉ app>/anh/`, **không** có mặt trong
  `CORE_ASSETS` của `web/sw.js`.
* `lib/services/illustration_service.dart` chỉ tải ảnh của thẻ **đã kích hoạt**,
  ba ảnh một lượt. Thẻ trong thư viện chưa kích hoạt thì bỏ qua.
* Thiếu ảnh **không** được cản việc học: thẻ vẫn hiện đủ từ, phiên âm, nghĩa và
  câu ví dụ. Ảnh hỏng thì để trống, tuyệt đối không hiện biểu tượng lỗi.

### Kho ảnh phải sống sót qua mỗi lần triển khai

`CACHE_ANH = 'leitner-anh-v1'` **cố ý không gắn với mã build**, và bước
`activate` phải giữ lại nó:

```js
.filter((name) => name !== CACHE_NAME && name !== CACHE_ANH)
```

Bỏ vế thứ hai là mỗi lần triển khai người dùng mất sạch ảnh đã tải — hàng chục MB
tải lại từ đầu. `test/web_shell_test.dart` khoá lại cả hai điều này.

Tra kho ảnh dùng `{ ignoreSearch: true }`: ảnh là nội dung bất biến, phần sau dấu
hỏi không đổi nội dung. **Đo được thật trên trình duyệt:** không có cờ đó thì
`anh/x.png?v=2` trượt kho và ảnh biến mất khi mất mạng, trong khi `anh/x.png`
vẫn hiện.

Cách chạy lại phép kiểm chứng offline: xem `web/anh/README.md`.

## Cây widget trên Navigator — phải tự cấp Overlay

Phần bọc trong `MaterialApp.builder` nằm **TRÊN** Navigator, mà `Overlay` lại do
chính Navigator tạo ra. Vì vậy mọi widget cần Overlay đặt ở đó — `Tooltip`,
`PopupMenuButton`, `DropdownButton` — sẽ ném:

```
No Overlay widget found.
RawTooltip widgets require an Overlay widget ancestor
```

Đã xảy ra thật (28/08/2026): hai dải thông báo bọc ngoài cùng đều có `IconButton`
kèm `tooltip`, nên **mỗi lần dải hiện là một lần ném lỗi khi dựng**.

Cách chữa: bọc bằng `Overlay.wrap(child: ...)` của chính Flutter. Đừng tự viết
lớp bọc Overlay: bản tự viết dễ quên gọi `remove()` trước `dispose()` và sẽ nổ
assert lúc gỡ cây.

### Hậu quả thật của lỗi này — nó KHÔNG chỉ là một dòng lỗi

Khi `Tooltip` ném lỗi lúc dựng, Flutter thay cả nhánh đó bằng **ErrorWidget**.
Trong bản phát hành, `RenderErrorBox` phình ra chiếm hết vùng của dải và **nuốt
trọn mọi cú chạm**, còn nút thật bị đẩy ra ngoài màn hình (đo được: `y = 50041`).

Đã xảy ra thật trên iPhone (28/08/2026), và triệu chứng đánh lừa hoàn toàn:

* Mọi nút **trong dải** chết, mọi nút khác vẫn bình thường.
* Độ trễ chạm đo được **0–13 ms** — vì `Listener` ở gốc cây là
  `HitTestBehavior.translucent`, nó **ghi nhận cú chạm kể cả khi không nút nào
  nhận được**. Nhật ký chạm đẹp không chứng minh nút có ăn.
* Kết quả là vòng luẩn quẩn: dải báo có bản mới, mà nút nạp bản mới lại chết.

Vì vậy hai dải thông báo có **quy tắc riêng, nghiêm hơn**: chúng là lối thoát duy
nhất của người dùng đã cài app vào màn hình chính (không thanh địa chỉ, không nút
tải lại), nên **không được phép chứa bất cứ widget nào cần Overlay** — kể cả khi
app.dart đã có `Overlay.wrap`. Dùng `Icon(semanticLabel: ...)` thay cho `tooltip`.
Nhóm test *"Dải phải bấm được KỂ CẢ khi không có Overlay"* trong
`test/standalone_touch_test.dart` khoá lại điều này; **đừng gỡ**.

## Dải thông báo — xếp dọc, đừng đè lên

Hai dải (`update_banner`, `error_banner`) từng dùng `Stack` + `Positioned(top: 0)`
để khỏi làm giao diện nhảy. Cái giá quá đắt: dải **phủ kín thanh tiêu đề**, mất
chữ "Leitner" và mất luôn nút Chẩn đoán bên cạnh. Nay dùng `Column` + `Expanded`,
kèm `MediaQuery.removePadding(removeTop: true)` cho phần dưới để không chừa lề an
toàn hai lần.

## Kiểm tra cập nhật — theo sự kiện, không theo nhịp

Không dùng `Timer.periodic` ở gốc cây widget. Hỏi lại mỗi 2–3 giây là đánh thức
luồng chính vô ích suốt phiên. Ba thời điểm đủ dùng: lúc mở app, khi phía trình
duyệt gọi sang (`__leitnerBaoCapNhat` / `__leitnerBaoLoi` trong `web/index.html`),
và khi app quay lại từ nền (`WidgetsBindingObserver.didChangeAppLifecycleState`).

## Định nghĩa "đã thuộc"

Thẻ **đang ở Hộp 5** thì tính là đã thuộc. Không có điều kiện nào thêm.
Dùng cho số liệu "tổng số từ đã thuộc" ở màn hình Tổng quan.

## Giãn cách thật của lịch ôn

Bảng ở SOP mục 3.1 chỉ ghi khoảng cách **tối thiểu**. Giãn cách thật đo được
(xem `test/schedule_matrix_test.dart`, test tự khoá lại các con số này):

| Hộp | Tối thiểu | Dải thật | Khi ôn đúng hạn |
|---|---|---|---|
| 1 | 1 | 1 ngày | luôn 1 ngày |
| 2 | 2 | 2–4 ngày | |
| 3 | 5 | 5–11 ngày | |
| 4 | **13** (SOP ghi 12) | 13–19 ngày | **nhóm chẵn 18 ngày, nhóm lẻ 19 ngày** |
| 5 | 20 | 20–50 ngày | |

**Hộp 4 dùng 13 ngày chứ không phải 12 như bảng mục 3.1.** Đây là sửa đổi có chủ
ý, đã được duyệt. Với 12 ngày: thẻ chỉ lên Hộp 4 từ Hộp 3, mà Hộp 3 chỉ đến hạn
Thứ Ba; Thứ Ba cộng 12 rơi ĐÚNG Chủ Nhật nên nhóm lẻ dừng ngay (12 ngày) còn
nhóm chẵn đi tiếp tới Thứ Bảy (18 ngày) — chênh 50%, mà việc thẻ rơi vào nhóm
nào lại do mã băm `id` quyết định, hoàn toàn ngẫu nhiên và không liên quan tới độ
khó của từ. Với 13 ngày, Thứ Ba cộng 13 rơi vào Thứ Hai nên cả hai nhóm đều phải
đi tiếp: chẵn 18, lẻ 19. Ví dụ thứ ba ở mục 3.3 của SOP không đổi kết quả
(Chủ Nhật 04/05 cộng 13 rơi đúng Thứ Bảy 17/05).

Con số "mỗi thẻ 14 ngày một lần" ở mục 3.2 là **sai thực tế**. Thẻ chỉ đi qua
Hộp 4 đúng một lần: đúng thì lên thẳng Hộp 5, sai thì rơi về Hộp 1 — không có
nhánh nào đưa thẻ ở Hộp 4 quay lại chính Hộp 4.

## Phạm vi ứng dụng

- **Flutter web PWA**, chỉ chạy trên trình duyệt.
- **Không** có Android, **không** có iOS, **không** có desktop.
- **Không** có máy chủ backend, **không** có đăng nhập/tài khoản.
- Toàn bộ dữ liệu nằm ở máy người dùng (Hive trên IndexedDB).

## Môi trường

- Flutter 3.47.1 stable ở `D:\flutter` (Dart 3.13.1).
- Chrome đã cài — dùng để chạy thử: `flutter run -d chrome`.
- Không có Android Studio / Xcode / Visual Studio, và **không cần** cho dự án này.

## Lệnh hay dùng

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build web
flutter run -d chrome
```
