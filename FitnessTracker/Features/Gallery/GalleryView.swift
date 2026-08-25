//
//  GalleryView.swift
//  Photo checklist, smart albums, before/after slider, time-lapse generator.
//

import SwiftUI
import SwiftData

struct GalleryView: View {
    @Environment(\.modelContext) private var context
    @Query private var logs: [DailyLog]
    @State private var selectedAlbum: Album = .morning

    enum Album: String, CaseIterable, Identifiable {
        case morning, medication, supplements, all
        var id: String { rawValue }
        var titleAR: String {
            switch self {
            case .morning: return "5:00 AM Progress"
            case .medication: return "الدواء"
            case .supplements: return "المكملات"
            case .all: return "كل الصور"
            }
        }
        var albumKey: String? {
            switch self {
            case .morning: return "morning"
            case .medication: return "medication"
            case .supplements: return "supplements"
            case .all: return nil
            }
        }
    }

    private var allPhotos: [ProgressPhoto] {
        logs.flatMap(\.photos).sorted { $0.takenAt < $1.takenAt }
    }

    private var filteredPhotos: [ProgressPhoto] {
        guard let key = selectedAlbum.albumKey else { return allPhotos }
        return allPhotos.filter { $0.albumKey == key }
    }

    private var morningPhotos: [ProgressPhoto] { allPhotos.filter { $0.albumKey == "morning" } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    albumPicker

                    if selectedAlbum == .morning, morningPhotos.count >= 2 {
                        beforeAfterCard
                        timelapseCard
                    }

                    photoGrid
                }
                .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("المعرض")
        }
    }

    private var albumPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Album.allCases) { album in
                    Button {
                        selectedAlbum = album
                    } label: {
                        Text(album.titleAR)
                            .font(.subheadline.weight(selectedAlbum == album ? .bold : .regular))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(selectedAlbum == album ? AppTheme.accent : AppTheme.card,
                                        in: Capsule())
                            .foregroundStyle(selectedAlbum == album ? .black : AppTheme.textPrimary)
                    }
                }
            }
        }
    }

    private var beforeAfterCard: some View {
        CardView {
            Text("مقارنة قبل / بعد")
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            if let first = morningPhotos.first, let last = morningPhotos.last {
                BeforeAfterSlider(before: first, after: last)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var timelapseCard: some View {
        CardView {
            Text("فيديو التطور")
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            TimelapseButton(photos: morningPhotos)
        }
    }

    private var photoGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(filteredPhotos) { photo in
                PhotoThumbnail(photo: photo)
            }
        }
    }
}

private struct PhotoThumbnail: View {
    let photo: ProgressPhoto
    @State private var showExportConfirmation = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = PhotoStorageService.shared.loadImage(fileName: photo.fileName) {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipped()
            } else {
                Rectangle().fill(AppTheme.cardElevated).frame(width: 100, height: 100)
            }
            if let weight = photo.weightKg {
                Text("\(weight, specifier: "%.1f") كجم")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.black.opacity(0.6))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(4)
            }
        }
        .contextMenu {
            Button("تصدير إلى الصور") {
                Task { try? await PhotoStorageService.shared.exportToSystemPhotoLibrary(fileName: photo.fileName) }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct BeforeAfterSlider: View {
    let before: ProgressPhoto
    let after: ProgressPhoto
    @State private var dividerX: CGFloat = 0.5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                if let img = PhotoStorageService.shared.loadImage(fileName: after.fileName) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height).clipped()
                }
                if let img = PhotoStorageService.shared.loadImage(fileName: before.fileName) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height).clipped()
                        .mask(alignment: .leading) {
                            Rectangle().frame(width: geo.size.width * dividerX)
                        }
                }
                Rectangle()
                    .fill(AppTheme.accent)
                    .frame(width: 3)
                    .position(x: geo.size.width * dividerX, y: geo.size.height / 2)
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 32, height: 32)
                    .overlay(Image(systemName: "arrow.left.and.right").foregroundStyle(.black).font(.caption))
                    .position(x: geo.size.width * dividerX, y: geo.size.height / 2)
            }
            .gesture(
                DragGesture().onChanged { value in
                    dividerX = min(max(value.location.x / geo.size.width, 0), 1)
                }
            )
        }
    }
}

private struct TimelapseButton: View {
    let photos: [ProgressPhoto]
    @State private var isGenerating = false
    @State private var progress: Double = 0
    @State private var outputURL: URL?

    var body: some View {
        VStack(spacing: 8) {
            Button {
                generate()
            } label: {
                HStack {
                    if isGenerating { ProgressView(value: progress).tint(.black) }
                    Text(isGenerating ? "جاري الإنشاء…" : "إنشاء فيديو تايم لابس")
                }
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isGenerating)

            if let outputURL {
                ShareLink(item: outputURL) {
                    Label("مشاركة الفيديو", systemImage: "square.and.arrow.up")
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    private func generate() {
        isGenerating = true
        progress = 0
        Task {
            do {
                let url = try await TimelapseGenerator.generate(photos: photos) { p in
                    Task { @MainActor in progress = p }
                }
                await MainActor.run { outputURL = url; isGenerating = false }
            } catch {
                await MainActor.run { isGenerating = false }
            }
        }
    }
}
