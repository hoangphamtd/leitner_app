'use strict';

// Service worker tự viết cho Leitner.
//
// Vì sao phải tự viết: từ Flutter 3.2x, service worker do `flutter build web`
// sinh ra đã bị khai tử — file `flutter_service_worker.js` bây giờ KHÔNG cache
// gì cả, nó chỉ tự gỡ đăng ký chính mình. Dùng cấu hình mặc định thì app không
// chạy nổi khi mất mạng, mà chạy offline lại là một trong ba nguyên tắc bắt
// buộc của dự án. Đã kiểm chứng: tắt máy chủ rồi tải lại trang thì trình duyệt
// báo trang lỗi.
//
// Chiến lược: nạp sẵn phần lõi lúc cài đặt, còn lại thì gặp gì cache nấy.
// Không dùng danh sách toàn bộ tài nguyên như bản Flutter cũ, vì danh sách đó
// phải sinh lại sau mỗi lần build và rất dễ lệch với thực tế.

const CACHE_NAME = 'leitner-v1';

// Những file bắt buộc phải có để app khởi động được. Thiếu một trong số này thì
// mở offline chỉ ra trang trắng.
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
      // Nhận việc ngay, không chờ tab cũ đóng hết.
      await self.skipWaiting();
    })()
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      // Dọn cache của phiên bản cũ, nếu không mỗi lần đổi CACHE_NAME lại để lại
      // một kho rác trong máy người dùng.
      const names = await caches.keys();
      await Promise.all(
        names.filter((name) => name !== CACHE_NAME).map((name) => caches.delete(name))
      );
      await self.clients.claim();
    })()
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;

  // Chỉ lo phần đọc. Các phương thức khác không có gì để cache.
  if (request.method !== 'GET') return;

  // Bỏ qua tài nguyên của miền khác: app này không phụ thuộc miền ngoài nào,
  // mà cache bừa của miền khác thì vừa vô ích vừa khó gỡ.
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  // Yêu cầu điều hướng (mở trang, tải lại, mở từ màn hình chính) luôn phải trả
  // về được index.html, kể cả khi hoàn toàn mất mạng — đây chính là chỗ mà bản
  // mặc định của Flutter thất bại.
  if (request.mode === 'navigate') {
    event.respondWith(
      (async () => {
        try {
          const fresh = await fetch(request);
          const cache = await caches.open(CACHE_NAME);
          cache.put('index.html', fresh.clone());
          return fresh;
        } catch (error) {
          const cache = await caches.open(CACHE_NAME);
          const cached =
            (await cache.match('index.html')) || (await cache.match('./'));
          if (cached) return cached;
          throw error;
        }
      })()
    );
    return;
  }

  // Các tài nguyên còn lại: ưu tiên lấy từ cache cho nhanh và chạy được offline,
  // không có thì tải về rồi cache lại cho lần sau.
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
