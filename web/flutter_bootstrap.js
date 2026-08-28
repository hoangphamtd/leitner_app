// Bản khởi động tuỳ biến của Flutter.
//
// Có file này thì `flutter build web` dùng nó thay cho bản sinh tự động. Mục
// đích duy nhất: KHÔNG truyền `serviceWorkerSettings` vào loader, để Flutter
// không đăng ký `flutter_service_worker.js` của nó.
//
// Lý do: service worker của Flutter đã bị khai tử, bản sinh ra chỉ tự gỡ đăng
// ký chính mình và không cache gì. Nếu để nó chạy, nó sẽ chiếm mất phạm vi và
// gỡ luôn service worker riêng ở `sw.js` — thứ thật sự làm cho app chạy offline.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load();
