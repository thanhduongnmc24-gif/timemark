# TimeStampCam Pro (iOS) — Ứng Dụng Chụp Ảnh & Chọn Ảnh Đóng Dấu Thời Gian (Timemark Hòa Phát)

Dự án ứng dụng iOS viết bằng **SwiftUI + AVFoundation + CoreGraphics** được thiết kế theo đúng chuẩn quy trình **XcodeGen + GitHub Actions**: không cần máy Mac cá nhân, chỉ cần đẩy code lên GitHub là Action tự động sinh `TimeStampCamPro.xcodeproj`, biên dịch bản `Release` không ký (`CODE_SIGNING_ALLOWED=NO`) và đóng gói thành **`TimeStampCamPro.ipa`** để bạn tải về cài qua **TrollStore, ESign, Feather, Sideloadly hoặc AltStore**.

---

## Tính năng chính

1. **Chụp ảnh lưu thẳng vào Thư viện (Không hiện bảng hỏi lại)**:
   - Ngay khi bấm nút Chụp (hoặc bấm Lưu khi chọn ảnh từ mục `Có sẵn`), ảnh đã đóng dấu thời gian được **lưu thẳng vào Thư viện Ảnh iPhone** và **Bộ sưu tập trong ứng dụng** kèm thông báo nhanh, không bật hộp thoại hỏi xác nhận lại.

2. **Nút `"Ảnh đã chụp"` trên thanh đầu ứng dụng — Chọn nhiều ảnh & Chia sẻ qua Zalo, Facebook...**:
   - Nằm ngay trên thanh công cụ phía trên cùng (giữa nút Đèn Flash và nút Đổi Camera), hiển thị ảnh thu nhỏ vừa chụp cùng số lượng ảnh.
   - Mở danh sách toàn bộ ảnh đã được chụp bằng ứng dụng này, hỗ trợ **chạm để chọn nhiều ảnh cùng lúc** (hoặc **Chọn tất cả**) và bấm **Chia sẻ** để gửi hàng loạt qua **Zalo, Facebook, Messenger, AirDrop, Tin nhắn...**

3. **Thanh công cụ dưới cùng gọn gàng**:
   - Gồm 3 nút cân đối: **`Có sẵn`** (chọn ảnh từ Thư viện máy), **Nút Chụp / Quay Video** ở chính giữa, và **`Bản mẫu`** (mở bảng trượt chỉnh sửa mẫu) ở bên phải (đã lược bỏ nút `Tệp`).

4. **Khung đóng dấu thời gian (Watermark) chuẩn mẫu `HÒA PHÁT GANG THÉP`**:
   - **Logo phía trên giờ**: Tích hợp sẵn logo **`HOA PHAT GANG THÉP`** sắc nét (viền trắng chữ xanh chuẩn mẫu), đồng thời cho phép đổi sang **Logo chữ tùy chỉnh** hoặc **tải ảnh Logo PNG bất kỳ** từ máy.
   - **Giờ lớn + Vạch dọc màu cam + Ngày tháng & Thứ**: Hiển thị đúng phông chữ cao đậm (`21:55`), vạch dọc màu cam ngăn cách, bên phải là ngày tháng (`26/10/2026`) và thứ tiếng Việt (`Thứ Hai`).
   - **Khung mờ ghi chú Tổ / Kíp vận hành**: Khung nền xám mờ bo góc bên dưới hiển thị nội dung công việc (mặc định: `Tổ Vận hành - Kíp A X.CT1`), có sẵn danh sách chọn nhanh 1 chạm giữa Kíp A, Kíp B, Kíp C, Kíp D hoặc tự gõ nội dung mới.

---

## Cấu trúc thư mục dự án

```text
TimeMark/
├── .github/
│   └── workflows/
│       └── build-ipa.yml                  # GitHub Actions tự động build và xuất file .ipa
├── project.yml                            # Cấu hình XcodeGen (tự sinh .xcodeproj trên GitHub CI)
├── TimeStampCamPro/                       # Target ứng dụng chính (iOS 15.0+)
│   ├── TimeStampCamApp.swift              # Điểm khởi chạy ứng dụng (@main)
│   ├── Info.plist                         # Khai báo quyền Camera, Thư viện ảnh, Vị trí GPS
│   ├── TimeStampCamPro.entitlements       # Quyền ứng dụng phục vụ ký ldid / TrollStore / ESign
│   ├── Models/
│   │   └── WatermarkConfig.swift          # Quản lý dữ liệu giờ, ngày, thứ, kíp trực, bản mẫu
│   ├── Services/
│   │   ├── CameraService.swift            # Quản lý AVCaptureSession, Flash, Zoom 0.5x/1x/2x/10x
│   │   ├── CapturedPhotoStore.swift       # Quản lý & lưu trữ danh sách các ảnh chụp bởi ứng dụng
│   │   ├── LocationService.swift          # Quản lý GPS & địa chỉ tự động
│   │   └── WatermarkRenderer.swift        # Vẽ trực tiếp logo + giờ + khung ghi chú lên ảnh gốc
│   ├── Views/
│   │   ├── ContentView.swift              # Giao diện chính với nút "Ảnh đã chụp" trên thanh đầu
│   │   ├── AppPhotoGallerySheet.swift     # Bộ sưu tập ảnh đã chụp (chọn nhiều ảnh & chia sẻ Zalo/FB)
│   │   ├── WatermarkOverlayView.swift     # Khung hiển thị trực tiếp Logo + Giờ + Kíp trực
│   │   ├── EditWatermarkSheet.swift       # Bảng chỉnh sửa ngày giờ, kíp trực, logo
│   │   ├── TemplatePickerSheet.swift      # Bảng quản lý & chuyển đổi Bản mẫu (Presets)
│   │   └── ImagePickers.swift             # Bộ chọn ảnh Thư viện ("Có sẵn") & Chia sẻ hệ thống
│   └── Resources/
│       └── Assets.xcassets/               # Bộ AppIcon đầy đủ kích thước & Logo Hòa Phát Gang Thép
└── scripts/
    └── package_ipa.sh                     # Script đóng gói IPA nhanh nếu chạy trên máy Mac
```
