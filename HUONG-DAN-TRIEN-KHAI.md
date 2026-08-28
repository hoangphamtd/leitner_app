# Hướng dẫn triển khai Leitner App lên GitHub Pages

Tài liệu này dành cho người vận hành, không cần biết lập trình.

---

## 1. Địa chỉ app

```
https://hoangphamtd.github.io/leitner_app/
```

Kho mã: https://github.com/hoangphamtd/leitner_app

**Dấu gạch chéo cuối là bắt buộc.** Thiếu nó thì GitHub tự chuyển hướng, nhưng
gửi link cho người khác thì nên gửi đúng dạng có dấu gạch chéo.

---

## 2. Cập nhật app về sau

Mỗi lần sửa mã xong, chỉ cần đẩy lên nhánh `main`:

```bash
git add -A
git commit -m "mo ta ngan gon viec vua sua"
git push
```

Xong. GitHub tự build và cập nhật app, thường mất **3 đến 6 phút**.

Xem tiến trình: vào kho trên GitHub → tab **Actions** → dòng trên cùng.
Chấm xanh là xong, chấm vàng là đang chạy, chấm đỏ là hỏng.

### Người dùng có thấy bản mới ngay không?

Không ngay lập tức. App đã cài trên máy người dùng chạy bằng bản đã lưu sẵn
(service worker). Bản mới được nạp về ở lần mở kế tiếp, và **hiện ra ở lần mở
sau nữa**. Nói cách khác, người dùng thường thấy bản mới sau khi mở app hai lần.

Muốn họ thấy ngay: bảo họ đóng hẳn app rồi mở lại hai lần, hoặc tăng số phiên
bản `CACHE_NAME` trong `web/sw.js` (xem mục 5).

---

## 3. Khi workflow báo đỏ

Vào tab **Actions**, bấm vào lần chạy có chấm đỏ, bấm tiếp vào bước bị đỏ để
đọc thông báo lỗi. Ba nguyên nhân thường gặp:

### a) Bước "Chạy kiểm thử" đỏ

Có bài kiểm thử không đạt. Đây là **lá chắn có chủ ý**: workflow cố tình chạy
kiểm thử trước khi build, để mã hỏng không bao giờ lên tới người dùng.

Chạy ở máy để xem lỗi gì:

```bash
flutter test
```

Sửa cho xanh rồi đẩy lại.

### b) Bước "Soát tĩnh" đỏ

Mã có lỗi cú pháp hoặc vi phạm quy tắc. Chạy ở máy:

```bash
flutter analyze
```

### c) Bước "Cài Flutter" đỏ

Thường do phiên bản Flutter ghi trong workflow không còn tồn tại. Mở file
`.github/workflows/deploy.yml`, tìm dòng:

```yaml
flutter-version: '3.47.1'
```

Sửa cho khớp với phiên bản đang dùng ở máy. Xem bằng lệnh:

```bash
flutter --version
```

### Chạy lại mà không sửa gì

Đôi khi lỗi chỉ do mạng hoặc máy chủ GitHub trục trặc nhất thời. Vào Actions →
bấm vào lần chạy đỏ → nút **Re-run all jobs** ở góc trên bên phải.

---

## 4. Gửi link cho người khác cài vào điện thoại

Gửi đúng địa chỉ ở mục 1. Người nhận mở bằng trình duyệt điện thoại, app sẽ tự
hiện bảng hướng dẫn cài. Nếu họ bỏ qua, hướng dẫn tay:

**Trên iPhone (Safari):**
1. Bấm nút Chia sẻ ở thanh dưới
2. Kéo xuống, chọn **Thêm vào MH chính**
3. Bấm **Thêm** ở góc trên bên phải

**Trên Android (Chrome):**
1. Bấm nút ba chấm ở góc trên bên phải
2. Chọn **Cài đặt ứng dụng** hoặc **Thêm vào Màn hình chính**
3. Xác nhận **Cài đặt**

### Vì sao nên cài chứ đừng chỉ mở bằng trình duyệt

Toàn bộ tiến độ học nằm trong bộ nhớ của trình duyệt trên máy người dùng.
Trình duyệt có quyền dọn bộ nhớ đó khi máy hết dung lượng hoặc khi người dùng
xoá dữ liệu duyệt web. Cài vào màn hình chính thì dữ liệu được giữ chắc hơn
nhiều. App cũng nhắc người dùng chuyện này ngay trong bảng hướng dẫn.

### Nhắc người dùng sao lưu

App tự nhắc sau 14 ngày không sao lưu. Đường đi: **Cài đặt → Sao lưu tiến độ →
XUẤT**, ra một file `.json` nên cất vào Drive hoặc gửi vào Zalo cho chính mình.
Mất máy hay đổi điện thoại thì dùng nút **NHẬP** để khôi phục.

---

## 5. Ba chỗ dễ hỏng — đọc trước khi sửa

### a) Đổi tên kho thì phải sửa `--base-href`

GitHub Pages đặt app trong thư mục con mang **đúng tên kho**. Trong
`.github/workflows/deploy.yml` có dòng:

```yaml
run: flutter build web --no-web-resources-cdn --base-href /leitner_app/
```

Đổi tên kho thành `abc` thì phải sửa thành `--base-href /abc/`.

**Triệu chứng khi quên:** app ra **trang trắng hoàn toàn**, không báo lỗi gì.

### b) Đừng bỏ `--no-web-resources-cdn`

Không có tham số này, app tải bộ vẽ đồ hoạ và phông chữ từ máy chủ Google. Khi
đó app **vẫn chạy bình thường lúc có mạng** nên rất dễ tưởng là ổn — nhưng người
dùng mở lần đầu lúc mất mạng sẽ hỏng.

### c) Sửa `web/sw.js` thì phải tăng số phiên bản

Trong `web/sw.js` có dòng:

```js
const CACHE_NAME = 'leitner-v1';
```

Sửa nội dung file này thì đổi thành `leitner-v2`, lần sau nữa là `v3`… Không đổi
thì máy người dùng vẫn chạy bản cũ đã lưu.

**Đừng xoá `web/sw.js` và `web/flutter_bootstrap.js`.** Hai file này do dự án tự
viết, không phải Flutter sinh ra. Từ Flutter 3.2x, service worker mặc định của
Flutter đã bị khai tử và không lưu gì cả — xoá hai file này là mất luôn khả năng
chạy khi không có mạng.

---

## 6. Vì sao kho để công khai

Ban đầu kho được tạo ở chế độ riêng tư, nhưng GitHub từ chối bật Pages với thông
báo *"Your current plan does not support GitHub Pages for this repository"* —
Pages cho kho riêng tư đòi gói trả phí. Vì vậy kho đã chuyển sang **công khai**.

Trước khi chuyển, mã nguồn đã được rà soát: không có khoá API, mật khẩu, file
`.env` hay bất kỳ thông tin nhạy cảm nào. Dữ liệu học của người dùng nằm trên máy
họ, không liên quan tới kho mã.

Một điều nên biết: lịch sử commit mang địa chỉ email `hoangphamtd@gmail.com` và
giờ ai cũng đọc được. Đây là chuyện bình thường với mọi dự án mã nguồn mở. Muốn
kín email cho các commit về sau thì bật *Keep my email addresses private* trong
GitHub → Settings → Emails, rồi đổi `git config user.email` ở máy sang địa chỉ
dạng `...@users.noreply.github.com`.

Muốn kho kín hoàn toàn thì phải nâng lên **GitHub Pro** (khoảng 4 đô la Mỹ mỗi
tháng), sau đó chuyển kho về riêng tư — Pages vẫn chạy.

---

## 7. Kiểm tra nhanh sau mỗi lần triển khai

1. Mở địa chỉ app ở mục 1 → phải thấy màn hình Tổng quan, không phải trang trắng
2. Bấm **THÊM TỪ MỚI VÀO HỘP 1** → phải thấy số ở Hộp 1 tăng
3. Bật chế độ máy bay trên điện thoại rồi mở lại app → vẫn phải học được

Bước 3 là bước quan trọng nhất và cũng hay bị bỏ qua nhất.
