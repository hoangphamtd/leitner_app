# Ảnh minh hoạ

Thư mục này chứa ảnh minh hoạ của thẻ từ vựng. File ở đây được `flutter build web`
chép nguyên vào bản dựng và phục vụ tại `<địa chỉ app>/anh/<tên file>`.

## Quy tắc, đừng phá

**Ảnh KHÔNG được nạp sẵn lúc cài app.** Bộ đầy đủ có 3500 ảnh, khoảng 105 MB.
Nạp sẵn thì lần mở đầu tiên phải tải hết mới dùng được, và nhiều khả năng vượt
hạn mức lưu trữ của Safari trên iPhone. Vì vậy `CORE_ASSETS` trong `web/sw.js`
tuyệt đối không được liệt kê file nào trong thư mục này.

**Ảnh nằm ở kho cache RIÊNG, không gắn với mã build** (`CACHE_ANH` trong
`web/sw.js`). Bước `activate` xoá mọi kho khác `CACHE_NAME`, mà `CACHE_NAME` đổi
theo từng bản build — để ảnh chung kho đó thì mỗi lần triển khai là người dùng
mất sạch ảnh đã tải.

**Chỉ ảnh của thẻ ĐÃ KÍCH HOẠT mới được tải về.** Việc này do
`lib/services/illustration_service.dart` lo. Đây là chỗ giữ cho lượng tải xuống
nhỏ: người học thường chỉ kích hoạt vài chục tới vài trăm thẻ.

**Thiếu ảnh không được cản việc học.** Thẻ chưa có ảnh vẫn hiện đủ từ, phiên âm,
nghĩa và câu ví dụ; chỗ dành cho ảnh chỉ để trống. Không bao giờ hiện biểu tượng
lỗi.

## `mau-kiem-chung.png`

Ảnh 64×64 nặng 138 byte, giữ lại có chủ đích để chạy lại phép kiểm chứng offline:

1. `flutter build web --no-web-resources-cdn`
2. Thay `__BUILD_VERSION__` trong `build/web/sw.js` bằng một chuỗi bất kỳ.
3. Phục vụ `build/web` bằng `python -m http.server 8099`.
4. Mở `http://localhost:8099/`, đợi service worker cài xong.
5. Trong console: `await fetch('anh/mau-kiem-chung.png')` — ảnh vào kho.
6. **Tắt máy chủ.**
7. `new Image().src = 'anh/mau-kiem-chung.png'` phải vẫn vẽ được 64×64.

Kết quả đo thật ngày 28/08/2026, sau ba lần giả lập triển khai bản mới:
kho `leitner-anh-v1` sống sót, kho ứng dụng cũ bị dọn đúng như thiết kế, ảnh
vẫn hiện khi máy chủ đã chết. Ảnh chưa từng tải thì `Failed to fetch` — đối
chứng cho thấy máy chủ thật sự đã tắt.
