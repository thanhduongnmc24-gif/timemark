# TimeStampCam Pro (iOS) — Ứng Dụng Chụp Ảnh & Chọn Ảnh Đóng Dấu Thời Gian (Timemark Hòa Phát)

Dự án ứng dụng iOS viết bằng **SwiftUI + AVFoundation + CoreGraphics** được thiết kế theo đúng chuẩn quy trình **XcodeGen + GitHub Actions** như repo mẫu của bạn: không cần máy Mac cá nhân, chỉ cần đẩy code lên GitHub là Action tự động sinh `TimeStampCamPro.xcodeproj`, biên dịch bản `Release` không ký (`CODE_SIGNING_ALLOWED=NO`), gắn fake-sign bằng `ldid` và đóng gói thành **`TimeStampCamPro-Unsigned.ipa`** để bạn tải về cài qua **TrollStore, ESign, Feather, Sideloadly hoặc AltStore**.

---

## Tính năng chính (Thiết kế giống hệt ảnh mẫu đính kèm)

1. **Hỗ trợ cả 2 chế độ: Chụp hình trực tiếp hoặc Tự chọn ảnh có sẵn**:
   - **Chụp trực tiếp bằng Camera**: Hỗ trợ chuyển đổi Camera trước/sau, bật/tắt đèn Flash, và cột nút chọn mức thu phóng (`10`, `2`, `1x`, `0.5`) ở cạnh phải màn hình.
   - **Chọn ảnh từ Thư viện (`Có sẵn`) hoặc Ứng dụng Tệp (`Tệp`)**: Cho phép chọn bất kỳ bức ảnh nào đã chụp trước đó trong máy, hỗ trợ phóng to/thu nhỏ/kéo căn chỉnh khung hình rồi đóng dấu thời gian và lưu thành ảnh mới.

2. **Khung đóng dấu thời gian (Watermark) chuẩn mẫu `HÒA PHÁT GANG THÉP`**:
   - **Logo phía trên giờ**: Tích hợp sẵn logo **`HOA PHAT GANG THÉP`** sắc nét (viền trắng chữ xanh chuẩn mẫu), đồng thời cho phép đổi sang **Logo chữ tùy chỉnh** hoặc **tải ảnh Logo PNG bất kỳ** từ máy.
   - **Giờ lớn + Vạch dọc màu cam + Ngày tháng & Thứ**: Hiển thị đúng phông chữ cao đậm (`21:55`), vạch dọc màu cam ngăn cách, bên phải là ngày tháng (`26/10/2026`) và thứ tiếng Việt (`Thứ Hai`).
   - **Khung mờ ghi chú Tổ / Kíp vận hành**: Khung nền xám mờ bo góc bên dưới hiển thị nội dung công việc (mặc định: `Tổ Vận hành - Kíp A X.CT1`), có sẵn danh sách chọn nhanh 1 chạm giữa Kíp A, Kíp B, Kíp C, Kíp D hoặc tự gõ nội dung mới.

3. **Tự điền thời gian bất kỳ hoặc Chạy theo giờ thực tế**:
   - Chạm vào **biểu tượng cây bút (`square.and.pencil`)** bên phải hoặc chạm trực tiếp vào khung giờ để mở bảng chỉnh sửa:
     - Chọn nhanh ngày/giờ trên lịch hoặc **tự gõ giờ, ngày tháng, thứ bất kỳ** theo ý muốn.
     - Hoặc bật công tắc **"Tự động chạy theo giờ thực tế"** để đồng hồ tự nhảy theo thời gian thực.
   - Chạm vào **biểu tượng tâm ngắm định vị** bên dưới cây bút để tự động lấy địa chỉ / tọa độ GPS hiện tại gắn vào khung ghi chú.

---

## Cấu trúc thư mục dự án

```text
TimeStampCamPro/
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
│   │   ├── LocationService.swift          # Quản lý GPS & địa chỉ tự động
│   │   └── WatermarkRenderer.swift        # Vẽ trực tiếp logo + giờ + khung ghi chú lên ảnh gốc
│   ├── Views/
│   │   ├── ContentView.swift              # Giao diện chính giống hệt ảnh chụp màn hình
│   │   ├── WatermarkOverlayView.swift     # Khung hiển thị trực tiếp Logo + Giờ + Kíp trực
│   │   ├── EditWatermarkSheet.swift       # Bảng chỉnh sửa ngày giờ, kíp trực, logo
│   │   ├── TemplatePickerSheet.swift      # Bảng quản lý & chuyển đổi Bản mẫu (Presets)
│   │   └── ImagePickers.swift             # Bộ chọn ảnh Thư viện ("Có sẵn"), "Tệp" & Chia sẻ
│   └── Resources/
│       └── Assets.xcassets/               # Bộ AppIcon đầy đủ kích thước & Logo Hòa Phát Gang Thép
└── scripts/
    └── package_ipa.sh                     # Script đóng gói IPA nhanh nếu chạy trên máy Mac
```

---

## Hướng dẫn đưa lên GitHub để xuất file `.ipa` tự động

### Bước 1: Giải nén và đẩy code lên GitHub Repository mới
Giải nén file `TimeStampCamPro-iOS-Swift-IPA.zip`, mở Terminal (hoặc VS Code) tại thư mục dự án và chạy:

```bash
git init
git add .
git commit -m "Initial commit: TimeStampCam Pro iOS Swift"
git branch -M main
git remote add origin https://github.com/<TEN_GITHUB_CUA_BAN>/<TEN_REPO_MOI>.git
git push -u origin main
```

### Bước 2: Tải file `TimeStampCamPro-Unsigned.ipa` từ GitHub Actions
1. Mở kho lưu trữ (Repository) vừa tạo trên GitHub, chuyển sang tab **Actions**.
2. Chọn workflow **Build Unsigned iOS IPA** (tự động chạy ngay khi bạn `git push`, hoặc bạn có thể bấm **Run workflow**).
3. Chờ khoảng 2–3 phút để máy chủ `macos-14` cài đặt `XcodeGen`, biên dịch ứng dụng và đóng gói `.ipa`.
4. Tải file **`TimeStampCamPro-Unsigned.ipa`** tại mục **Artifacts** (hoặc trong mục **Releases** của repo) và cài vào iPhone qua **TrollStore, ESign, Feather, Sideloadly hoặc AltStore**.
