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
