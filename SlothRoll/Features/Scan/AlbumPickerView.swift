import SwiftUI

/// Sheet for choosing what a scan reads: all recent photos, or one album (Photos'
/// Screenshots album first, then the user's own).
struct AlbumPickerView: View {
    let viewModel: ScanViewModel
    @Binding var albumID: String
    @Binding var albumTitle: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row(title: "All recent photos", detail: "Newest screenshots and saved images", id: "")
                }
                Section {
                    if viewModel.isLoadingAlbums && viewModel.albums.isEmpty {
                        ProgressView()
                    } else if viewModel.albumsNeedAccess {
                        Text("Allow Photos access in Settings to pick an album.")
                            .foregroundStyle(.secondary)
                    } else if viewModel.albums.isEmpty {
                        Text("No albums with images yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.albums) { album in
                            row(title: album.title, detail: imageCountText(album.imageCount), id: album.id)
                        }
                    }
                } header: {
                    Text("Albums")
                } footer: {
                    Text("Keep screenshots in one album? Scan just that album, swipe through it, then clear out the junk in the Clean up tab.")
                }
            }
            .navigationTitle("Scan from")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await viewModel.loadAlbums() }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(title: String, detail: String, id: String) -> some View {
        Button {
            albumID = id
            albumTitle = id.isEmpty ? "" : title
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if albumID == id {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
        }
        .accessibilityAddTraits(albumID == id ? .isSelected : [])
    }

    private func imageCountText(_ count: Int) -> String {
        count == 1 ? "1 image" : "\(count) images"
    }
}
