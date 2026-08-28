import '../../widgets/install_guide_sheet.dart';

/// Bản dự phòng cho môi trường không phải trình duyệt (unit test chạy trên máy
/// ảo Dart). Luôn báo "đã cài" để không có lời mời nào bật lên trong test.
class PlatformInfo {
  const PlatformInfo();

  MobilePlatform get mobilePlatform => MobilePlatform.other;

  bool get isMobileBrowser => false;

  bool get isInstalled => true;
}
