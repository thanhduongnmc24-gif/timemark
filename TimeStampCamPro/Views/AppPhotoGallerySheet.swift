import SwiftUI
import UIKit

/// Màn hình Bộ sưu tập các ảnh đã chụp bằng ứng dụng TimeMark Pro
/// Tối ưu hóa tốc độ: Toàn bộ ảnh thu nhỏ lấy trực tiếp từ RAM (0ms), chọn nhiều ảnh và chia sẻ qua Zalo, Facebook mượt tức thì
struct AppPhotoGallerySheet: View {
    @ObservedObject var capturedStore: CapturedPhotoStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var selectedIDs: Set<UUID> = []
    @State private var previewItem: CapturedPhotoItem? = nil
    @State private var showDeleteConfirm: Bool = false
    @State private var isPreparingShare: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if capturedStore.items.isEmpty {
                    emptyStateView
                } else {
                    selectionStatusBanner

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(capturedStore.items) { item in
                                photoGridCell(for: item)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                    }

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
                            if selectedIDs.count == capturedStore.items.count {
                                selectedIDs.removeAll()
                            } else {
                                selectedIDs = Set(capturedStore.items.map { $0.id })
                            }
                        }
                    }
                }
            }
            .sheet(item: $previewItem) { item in
                SinglePhotoPreviewSheet(
                    item: item,
                    capturedStore: capturedStore,
                    onDelete: {
                        capturedStore.deleteItems(withIDs: [item.id])
                        selectedIDs.remove(item.id)
                    }
                )
            }
            .alert(isPresented: $showDeleteConfirm) {
                Alert(
                    title: Text("Xóa \(selectedIDs.count) ảnh đã chọn?"),
                    message: Text("Các ảnh này sẽ bị xóa khỏi bộ sưu tập trong ứng dụng (ảnh trong Thư viện iPhone vẫn giữ nguyên)."),
                    primaryButton: .destructive(Text("Xóa")) {
                        capturedStore.deleteItems(withIDs: selectedIDs)
                        selectedIDs.removeAll()
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
                .font(.system(size: 14, weight: .semibold))

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
        .padding(.vertical, 9)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Ô hiển thị từng bức ảnh trong lưới (Không dùng animation nặng khi chọn để phản hồi 0ms)
    private func photoGridCell(for item: CapturedPhotoItem) -> some View {
        let isSelected = selectedIDs.contains(item.id)

        return ZStack(alignment: .topTrailing) {
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
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Text(item.shortTimeBadge)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.62))
                            .clipShape(Capsule())

                        Spacer()

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
                    .padding(5)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isSelected ? Color(red: 0.98, green: 0.42, blue: 0.0) : Color.clear,
                        lineWidth: 3
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelected {
                    selectedIDs.remove(item.id)
                } else {
                    selectedIDs.insert(item.id)
                }
            }

            // Biểu tượng tích chọn ở góc phải trên
            ZStack {
                Circle()
                    .fill(isSelected ? Color(red: 0.98, green: 0.42, blue: 0.0) : Color.black.opacity(0.45))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1.6)
                    )

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white)
                }
            }
            .padding(6)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Thanh công cụ Chia sẻ & Xóa dưới cùng
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
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

                Button {
                    guard !selectedIDs.isEmpty && !isPreparingShare else { return }
                    isPreparingShare = true
                    capturedStore.prepareImagesForSharing(ids: selectedIDs) { imagesToShare in
                        isPreparingShare = false
                        guard !imagesToShare.isEmpty else { return }
                        ShareHelper.presentShareSheet(items: imagesToShare)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .bold))
                        Text(
                            selectedIDs.isEmpty
                                ? "Chọn ảnh để chia sẻ (Zalo, FB...)"
                                : (isPreparingShare ? "Đang mở chia sẻ..." : "Chia sẻ \(selectedIDs.count) ảnh (Zalo, Facebook...)")
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
                .disabled(selectedIDs.isEmpty || isPreparingShare)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52, weight: .light))
                .foregroundColor(.secondary)

            Text("Chưa có ảnh nào được chụp")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Các bức ảnh bạn chụp bằng ứng dụng sẽ tự động lưu vào Thư viện và xuất hiện tại đây để bạn chọn nhiều ảnh chia sẻ nhanh qua Zalo, Facebook...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

/// Màn hình phóng to xem chi tiết 1 bức ảnh (hiển thị ngay ảnh thu nhỏ trong 0ms và nạp ảnh nét ở nền)
struct SinglePhotoPreviewSheet: View {
    let item: CapturedPhotoItem
    @ObservedObject var capturedStore: CapturedPhotoStore
    let onDelete: () -> Void
    @Environment(\.presentationMode) private var presentationMode

    @State private var fullImage: UIImage? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if let img = fullImage ?? capturedStore.thumbnailImage(for: item) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                } else {
                    Spacer()
                    ProgressView()
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

                    Button {
                        if let img = fullImage ?? capturedStore.thumbnailImage(for: item) {
                            ShareHelper.presentShareSheet(items: [img])
                        }
                    } label: {
                        Label("Chia sẻ (Zalo, FB...)", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
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
            .onAppear {
                capturedStore.loadFullImageAsync(for: item) { loaded in
                    self.fullImage = loaded
                }
            }
        }
    }
}
