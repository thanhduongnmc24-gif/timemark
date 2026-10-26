import SwiftUI
import UIKit

/// Màn hình Bộ sưu tập các ảnh đã chụp bằng ứng dụng TimeMark Pro
/// Cho phép chọn nhiều ảnh cùng lúc và chia sẻ nhanh qua Zalo, Facebook, Messenger, AirDrop...
struct AppPhotoGallerySheet: View {
    @ObservedObject var capturedStore: CapturedPhotoStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var selectedIDs: Set<UUID> = []
    @State private var previewItem: CapturedPhotoItem? = nil
    @State private var showDeleteConfirm: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if capturedStore.items.isEmpty {
                    emptyStateView
                } else {
                    // Thanh hướng dẫn & trạng thái chọn nhanh
                    selectionStatusBanner

                    // Lưới danh sách ảnh đã chụp bằng ứng dụng
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(capturedStore.items) { item in
                                photoGridCell(for: item)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                    }

                    // Thanh công cụ dưới cùng: Xóa & Chia sẻ qua Zalo, Facebook...
                    bottomActionBar
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Ảnh đã chụp (\(capturedStore.items.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if !capturedStore.items.isEmpty {
                        Button(selectedIDs.count == capturedStore.items.count ? "Bỏ chọn" : "Chọn tất cả") {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if selectedIDs.count == capturedStore.items.count {
                                    selectedIDs.removeAll()
                                } else {
                                    selectedIDs = Set(capturedStore.items.map { $0.id })
                                }
                            }
                        }
                    }
                }
            }
            .sheet(item: $previewItem) { item in
                SinglePhotoPreviewSheet(
                    item: item,
                    image: capturedStore.fullImage(for: item),
                    onShare: { img in
                        ShareHelper.presentShareSheet(items: [img])
                    },
                    onDelete: {
                        capturedStore.deleteItems(withIDs: [item.id])
                        selectedIDs.remove(item.id)
                    }
                )
            }
            .alert(isPresented: $showDeleteConfirm) {
                Alert(
                    title: Text("Xóa \(selectedIDs.count) ảnh đã chọn?"),
                    message: Text("Các ảnh này sẽ bị xóa khỏi danh sách ảnh đã chụp trong ứng dụng (ảnh đã lưu trong Thư viện hệ thống của iPhone vẫn được giữ nguyên)."),
                    primaryButton: .destructive(Text("Xóa")) {
                        withAnimation {
                            capturedStore.deleteItems(withIDs: selectedIDs)
                            selectedIDs.removeAll()
                        }
                    },
                    secondaryButton: .cancel(Text("Hủy"))
                )
            }
        }
    }

    // MARK: - Thanh trạng thái chọn ảnh
    private var selectionStatusBanner: some View {
        HStack {
            Image(systemName: selectedIDs.isEmpty ? "hand.tap.fill" : "checkmark.circle.fill")
                .foregroundColor(selectedIDs.isEmpty ? .secondary : Color(red: 0.98, green: 0.42, blue: 0.0))
                .font(.system(size: 15, weight: .semibold))

            Text(
                selectedIDs.isEmpty
                    ? "Chạm vào ảnh để chọn nhiều ảnh và chia sẻ qua Zalo, Facebook..."
                    : "Đã chọn \(selectedIDs.count) ảnh — Bấm nút Chia sẻ bên dưới để gửi"
            )
            .font(.footnote.weight(.medium))
            .foregroundColor(selectedIDs.isEmpty ? .secondary : .primary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(
            Divider(),
            alignment: .bottom
        )
    }

    // MARK: - Ô hiển thị từng bức ảnh trong lưới
    private func photoGridCell(for item: CapturedPhotoItem) -> some View {
        let isSelected = selectedIDs.contains(item.id)

        return ZStack(alignment: .topTrailing) {
            // Ảnh thu nhỏ
            GeometryReader { geo in
                if let thumb = capturedStore.thumbnailImage(for: item) {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Color(.systemGray5)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        )
                }
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                // Nhãn giờ chụp ở góc dưới ảnh
                VStack {
                    Spacer()
                    HStack {
                        Text(item.shortTimeBadge)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())

                        Spacer()

                        // Nút phóng to xem chi tiết 1 ảnh
                        Button {
                            previewItem = item
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.black.opacity(0.62))
                                .clipShape(Circle())
                        }
                    }
                    .padding(6)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isSelected ? Color(red: 0.98, green: 0.42, blue: 0.0) : Color.clear,
                        lineWidth: 3
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.12)) {
                    if isSelected {
                        selectedIDs.remove(item.id)
                    } else {
                        selectedIDs.insert(item.id)
                    }
                }
            }

            // Biểu tượng tích chọn ở góc phải trên
            ZStack {
                Circle()
                    .fill(isSelected ? Color(red: 0.98, green: 0.42, blue: 0.0) : Color.black.opacity(0.45))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1.8)
                    )

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.white)
                }
            }
            .padding(7)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Thanh công cụ Chia sẻ & Xóa dưới cùng
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                // Nút Xóa các ảnh đã chọn
                Button {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Xóa")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(selectedIDs.isEmpty ? .gray : .red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(selectedIDs.isEmpty)

                // Nút Chia sẻ qua Zalo, Facebook, Messenger...
                Button {
                    let imagesToShare = capturedStore.fullImages(for: selectedIDs)
                    guard !imagesToShare.isEmpty else { return }
                    ShareHelper.presentShareSheet(items: imagesToShare)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .bold))
                        Text(
                            selectedIDs.isEmpty
                                ? "Chọn ảnh để chia sẻ (Zalo, FB...)"
                                : "Chia sẻ \(selectedIDs.count) ảnh (Zalo, Facebook...)"
                        )
                        .font(.subheadline.weight(.bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        selectedIDs.isEmpty
                            ? Color.gray.opacity(0.45)
                            : Color(red: 0.98, green: 0.42, blue: 0.0)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(selectedIDs.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Trạng thái khi chưa chụp ảnh nào
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52, weight: .light))
                .foregroundColor(.secondary)

            Text("Chưa có ảnh nào được chụp")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Các bức ảnh bạn chụp hoặc đóng dấu bằng ứng dụng sẽ tự động lưu vào Thư viện và xuất hiện tại đây để bạn chọn nhiều ảnh chia sẻ nhanh qua Zalo, Facebook...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

/// Màn hình phóng to xem chi tiết 1 bức ảnh trong bộ sưu tập
struct SinglePhotoPreviewSheet: View {
    let item: CapturedPhotoItem
    let image: UIImage?
    let onShare: (UIImage) -> Void
    let onDelete: () -> Void
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                } else {
                    Spacer()
                    Text("Không thể tải ảnh")
                        .foregroundColor(.secondary)
                    Spacer()
                }

                if !item.captionText.isEmpty {
                    Text(item.captionText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                HStack(spacing: 14) {
                    Button(role: .destructive) {
                        onDelete()
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Label("Xóa ảnh", systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)

                    if let img = image {
                        Button {
                            onShare(img)
                        } label: {
                            Label("Chia sẻ (Zalo, FB...)", systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .navigationTitle(item.formattedTime)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
