'use strict';

// Service worker tự viết cho Leitner.
//
// Vì sao phải tự viết: từ Flutter 3.2x, service worker do `flutter build web`
// sinh ra đã bị khai tử — `flutter_service_worker.js` không cache gì cả, nó chỉ
// tự gỡ đăng ký chính mình. Dùng cấu hình mặc định thì app không chạy nổi khi
// mất mạng, mà chạy offline là một trong ba nguyên tắc bắt buộc của dự án.
//
// ---------------------------------------------------------------------------
// BÀI HỌC TỪ MỘT LỖI THẬT — đọc trước khi sửa file này
// ---------------------------------------------------------------------------
// Bản đầu tiên của file này khiến người dùng KẸT CỨNG ở bản cũ: đẩy bản mới lên
// máy chủ mà máy họ vẫn chạy bản cũ, không có cách nào biết. Hai nguyên nhân
// cộng hưởng:
//
//   1. `CACHE_NAME` là hằng số cố định. Sửa app không làm đổi nội dung file
//      này, nên trình duyệt coi service worker y hệt bản cũ và KHÔNG cài lại.
//      Không cài lại thì `activate` không chạy, cache cũ không bao giờ bị dọn.
//
//   2. Mọi tài nguyên đều lấy cache trước. Mà `main.dart.js` — chứa TOÀN BỘ mã
//      ứng dụng — có tên cố định, không kèm mã băm. Vậy là dù `index.html` được
//      tải mới, nó vẫn nạp đúng file mã cũ nằm trong cache.
//
// Cách chữa, và cũng là hai điều tuyệt đối không được phá:
//
//   * `BUILD_VERSION` được thay bằng mã build thật ở khâu triển khai, nên nội
//     dung file này đổi sau mỗi lần build. Trình duyệt thấy khác byte thì mới
//     chịu cài service worker mới.
//   * Nhóm file "khung ứng dụng" lấy MẠNG TRƯỚC. Chậm hơn một chút khi mạng
//     yếu, đổi lại người dùng không bao giờ kẹt ở bản cũ.
// ---------------------------------------------------------------------------

// Khâu triển khai thay chuỗi này bằng mã commit. Chạy ở máy phát triển thì giữ
// nguyên, và đó cũng là dấu hiệu nhận biết bản chưa qua triển khai.
const BUILD_VERSION = '__BUILD_VERSION__';

// Tên kho cache gắn với phiên bản build. Đổi tên đồng nghĩa với việc `activate`
// sẽ dọn sạch kho cũ và nạp lại toàn bộ từ máy chủ.
const CACHE_NAME = 'leitner-' + BUILD_VERSION;

// Khung ứng dụng: những file đổi theo từng bản build và có tên CỐ ĐỊNH.
// Vì tên không đổi nên cache không tự phân biệt được bản cũ với bản mới —
// nhóm này bắt buộc phải lấy mạng trước.
const APP_SHELL = [
  '',
  '/',
  'index.html',
  'flutter_bootstrap.js',
  'main.dart.js',
  'manifest.json',
];

// Nạp sẵn lúc cài để lần mở đầu tiên khi mất mạng vẫn chạy được.
const CORE_ASSETS = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'main.dart.js',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
];

/// Yêu cầu này có thuộc nhóm khung ứng dụng không.
function laKhungUngDung(url) {
  const duongDan = url.pathname;
  return APP_SHELL.some((ten) => {
    if (ten === '' || ten === '/') return duongDan.endsWith('/');
    return duongDan.endsWith('/' + ten);
  });
}

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE_NAME);
      // Dùng vòng lặp thay cho cache.addAll: addAll thất bại toàn bộ nếu chỉ
      // một file lỗi, mà vài file trong danh sách có thể vắng mặt tuỳ cấu hình
      // build. Thà cache được bao nhiêu hay bấy nhiêu.
      await Promise.all(
        CORE_ASSETS.map(async (path) => {
          try {
            const response = await fetch(path, { cache: 'reload' });
            if (response.ok) await cache.put(path, response);
          } catch (error) {
            console.warn('[sw] Không nạp sẵn được', path, error);
          }
        })
      );
      // Nhận việc ngay, không xếp hàng chờ tab cũ đóng hết. Không có dòng này
      // thì bản mới nằm im ở trạng thái chờ cho tới khi người dùng đóng sạch
      // mọi tab — trên điện thoại gần như không bao giờ xảy ra.
      await self.skipWaiting();
    })()
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      // Dọn kho của mọi phiên bản khác. Đây là chỗ khiến bản mới thật sự thay
      // được bản cũ: kho rỗng thì lần tải kế tiếp lấy hết từ máy chủ.
      const names = await caches.keys();
      await Promise.all(
        names
          .filter((name) => name !== CACHE_NAME)
          .map((name) => caches.delete(name))
      );
      // Chiếm quyền điều khiển các tab đang mở ngay lập tức.
      await self.clients.claim();
    })()
  );
});

self.addEventListener('message', (event) => {
  // Cho phép trang chủ động giục service worker mới vào việc, dùng khi người
  // dùng bấm nút "Tải lại" trên dải thông báo cập nhật.
  if (event.data === 'skipWaiting') self.skipWaiting();
});

self.addEventListener('fetch', (event) => {
  const request = event.request;

  // Chỉ lo phần đọc. Các phương thức khác không có gì để cache.
  if (request.method !== 'GET') return;

  // Bỏ qua tài nguyên của miền khác: app này không phụ thuộc miền ngoài nào,
  // mà cache bừa của miền khác thì vừa vô ích vừa khó gỡ.
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  // Yêu cầu điều hướng và các file khung ứng dụng: LẤY MẠNG TRƯỚC.
  //
  // Đây là điểm mấu chốt đã nói ở đầu file. Những file này mang mã của bản build
  // mà tên lại cố định, nên lấy cache trước là cầm chắc chuyện phục vụ bản cũ.
  // Mất mạng thì mới lùi về cache — lúc đó bản cũ vẫn hơn là không có gì.
  if (request.mode === 'navigate' || laKhungUngDung(url)) {
    event.respondWith(
      (async () => {
        try {
          const fresh = await fetch(request);
          if (fresh && fresh.status === 200) {
            const cache = await caches.open(CACHE_NAME);
            cache.put(request, fresh.clone());
          }
          return fresh;
        } catch (error) {
          const cache = await caches.open(CACHE_NAME);
          const cached =
            (await cache.match(request)) ||
            (await cache.match('index.html')) ||
            (await cache.match('./'));
          if (cached) return cached;
          throw error;
        }
      })()
    );
    return;
  }

  // Còn lại là tài nguyên nặng và gần như bất biến trong một bản build:
  // CanvasKit, phông chữ, biểu tượng. Nhóm này lấy cache trước cho nhanh và để
  // chạy được offline; kho cache đã được đặt tên theo phiên bản nên không sợ
  // lẫn giữa hai bản build.
  event.respondWith(
    (async () => {
      const cache = await caches.open(CACHE_NAME);
      const cached = await cache.match(request);
      if (cached) return cached;

      const response = await fetch(request);
      // Chỉ cache phản hồi bình thường. Phản hồi lỗi hoặc phản hồi mờ
      // (opaque) mà cache lại thì lần sau offline sẽ trả về đúng cái lỗi đó.
      if (response && response.status === 200 && response.type === 'basic') {
        cache.put(request, response.clone());
      }
      return response;
    })()
  );
});
