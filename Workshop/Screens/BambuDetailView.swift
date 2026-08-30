import SwiftUI
import UniformTypeIdentifiers
import NintekKit

/// Local image gallery, metadata, import notes, and downloadable files for one
/// public 3D project imported through Bambu Hub.
struct BambuDetailView: View {
    let api: WorkshopAPI
    let bambuId: Int
    let onChanged: () -> Void

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var project: BambuProject?
    @State private var loading = true
    @State private var loadError: String?
    @State private var gallery: GalleryPreview?
    @State private var showEditForm = false
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var deleteError: String?

    @State private var downloadingAssetId: Int?
    @State private var deletingAssetId: Int?
    @State private var assetActionFailure: AssetActionFailure?
    @State private var shareURL: IdentifiableURL?
    @State private var sharedDirectoryURL: URL?
    @State private var showFileImporter = false
    @State private var fileImportError: String?
    @State private var uploads: [UploadEntry] = []
    @State private var pendingDeleteAsset: BambuAsset?

    var body: some View {
        ScrollView {
            if let project {
                VStack(alignment: .leading, spacing: 28) {
                    hero(project)
                    titleSection(project)
                    metadataSection(project)
                    if let description = project.description, !description.isEmpty {
                        section("About This Project") {
                            Text(description)
                                .font(.body)
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    makerWorldProtectedFiles(project)
                    warningSection(project)
                    if !imageURLs(project).isEmpty {
                        gallerySection(project)
                    }
                    filesSection(project)
                    if let deleteError {
                        Text(deleteError)
                            .font(.footnote)
                            .foregroundStyle(Theme.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("Delete error: \(deleteError)")
                    }
                }
                .contentColumn(900)
                .padding(20)
            } else if loading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else if let loadError {
                loadFailure(loadError)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            UploadProgressPanel(uploads: uploads) { id in
                uploads.removeAll { $0.id == id }
            }
            .padding(16)
        }
        .boardBackground()
        .navigationTitle(project?.title ?? "Bambu Hub")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if project != nil, !model.isDemoMode {
                if deleting {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView()
                            .frame(width: 44, height: 44)
                            .accessibilityLabel("Deleting project")
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        BoardToolbarButton(
                            symbol: "pencil",
                            label: "Edit project",
                            tone: .amber
                        ) {
                            showEditForm = true
                        }
                    }
                    .boardToolbarItem()
                    ToolbarItem(placement: .topBarTrailing) {
                        BoardToolbarButton(
                            symbol: "trash",
                            label: "Delete project",
                            tone: .danger
                        ) {
                            confirmDelete = true
                        }
                    }
                    .boardToolbarItem()
                }
            }
        }
        .confirmationDialog(
            "Delete this 3D project and its local files?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Project", role: .destructive) {
                Task { await deleteProject() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Workshop will permanently remove the imported project, images, models, and other stored files. This cannot be undone.")
        }
        .confirmationDialog(
            "Delete this local file?",
            isPresented: confirmingAssetDelete,
            titleVisibility: .visible
        ) {
            if let asset = pendingDeleteAsset {
                Button("Delete \(asset.filename)", role: .destructive) {
                    Task { await deleteAsset(asset) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes only the selected local file from the Workshop project. It does not change the original provider page.")
        }
        .task { await load() }
        .refreshable { await load() }
        .fullScreenCover(item: $gallery) { ImageLightbox(preview: $0) }
        .sheet(isPresented: $showEditForm) {
            BambuProjectFormView(api: api, bambuId: bambuId) { _ in
                onChanged()
                Task { await load() }
            }
        }
        .sheet(item: $shareURL, onDismiss: cleanupSharedFile) {
            ActivityShareSheet(items: [$0.url])
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: Self.supportedImportTypes,
            allowsMultipleSelection: true
        ) { result in
            Task { await importFiles(result) }
        }
    }

    @ViewBuilder
    private func hero(_ project: BambuProject) -> some View {
        let urls = imageURLs(project)
        if !urls.isEmpty {
            let index = heroIndex(project, urls: urls)
            Button {
                gallery = GalleryPreview(urls: urls, index: index)
            } label: {
                Color.clear
                    .aspectRatio(16.0 / 10.0, contentMode: .fit)
                    .overlay {
                        AuthImage(
                            url: urls[index],
                            contentMode: .fill,
                            placeholderSymbol: "cube.fill"
                        )
                        .clipped()
                        .allowsHitTesting(false)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.rHero, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: Theme.rHero, style: .continuous))
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .accessibilityLabel("Open image gallery, \(urls.count) image\(urls.count == 1 ? "" : "s")")
        } else {
            Color.clear
                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                .overlay {
                    PlanCanvasBackground()
                        .overlay {
                            VStack(spacing: 10) {
                                Image(systemName: project.sourceSite.workshopSymbol)
                                    .font(.system(size: 36, weight: .medium))
                                Text("No local preview image")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            }
                            .foregroundStyle(Theme.muted)
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.rHero, style: .continuous))
                .accessibilityElement(children: .combine)
        }
    }

    private func titleSection(_ project: BambuProject) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "cube.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.accentDeep)
                .frame(width: 42, height: 42)
                .background(
                    Theme.tint(Theme.accent),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 8) {
                Text(project.title.isEmpty ? "Untitled" : project.title)
                    .font(Theme.display(24))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Flag(project.sourceSite.workshopDisplayName, tone: .steel)
                if let source = BambuUI.httpURL(project.sourceUrl) {
                    Link(destination: source) {
                        Label(
                            "View on \(project.sourceSite.workshopDisplayName)",
                            systemImage: "arrow.up.forward.square"
                        )
                        .font(.subheadline)
                        .foregroundStyle(Theme.accentDeep)
                        .minimumHitTarget()
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func metadataSection(_ project: BambuProject) -> some View {
        VStack(spacing: 0) {
            metadataRow("Images", value: project.imageCount.formatted(), symbol: "photo")
            Divider().overlay(Theme.line)
            metadataRow("Local files", value: project.fileCount.formatted(), symbol: "doc.zipper")
            if let creator = project.creatorName, !creator.isEmpty {
                Divider().overlay(Theme.line)
                metadataRow("Creator", value: creator, symbol: "person")
            }
            if let license = project.licenseName, !license.isEmpty {
                Divider().overlay(Theme.line)
                metadataRow("License", value: license, symbol: "checkmark.seal")
            }
            if let modelId = project.sourceModelId, !modelId.isEmpty {
                Divider().overlay(Theme.line)
                metadataRow("Model ID", value: modelId, symbol: "number")
            }
        }
        .planGlass(elevated: false)
    }

    private func metadataRow(_ label: String, value: String, symbol: String) -> some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
        } label: {
            Label(label, systemImage: symbol)
                .foregroundStyle(Theme.muted)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
    }

    @ViewBuilder
    private func makerWorldProtectedFiles(_ project: BambuProject) -> some View {
        if project.sourceSite == .makerworld {
            section("Protected MakerWorld Files") {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Add originals without sharing your account", systemImage: "lock.shield")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Sign in on MakerWorld, download the protected originals there, then return to Workshop and choose Add Files. Workshop never asks for or stores MakerWorld credentials or cookies.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .planGlass(elevated: false)
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder
    private func warningSection(_ project: BambuProject) -> some View {
        let warnings = BambuUI.uniqueWarnings(project.importWarnings)
        if !warnings.isEmpty {
            section("Import Notes") {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .frame(width: 22, height: 22)
                                .accessibilityHidden(true)
                            Text(warning)
                                .font(.footnote)
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Import note: \(warning)")
                    }
                }
                .padding(16)
                .planGlass(elevated: false)
            }
        }
    }

    private func gallerySection(_ project: BambuProject) -> some View {
        let urls = imageURLs(project)
        return section("Local Images", count: urls.count) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
                spacing: 10
            ) {
                ForEach(Array(urls.enumerated()), id: \.element) { index, url in
                    Button {
                        gallery = GalleryPreview(urls: urls, index: index)
                    } label: {
                        Color.clear
                            .aspectRatio(4.0 / 3.0, contentMode: .fit)
                            .overlay {
                                AuthImage(url: url, contentMode: .fill)
                                    .clipped()
                                    .allowsHitTesting(false)
                            }
                            .clipShape(
                                RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                            )
                            .contentShape(
                                RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open local image \(index + 1) of \(urls.count)")
                }
            }
        }
    }

    private func filesSection(_ project: BambuProject) -> some View {
        let assets = project.workshopFileAssets
        return section("Local Files", count: assets.count) {
            if !model.isDemoMode {
                Button {
                    showFileImporter = true
                } label: {
                    Label("Add Files", systemImage: "doc.badge.plus")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.accentDeep)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            Theme.tint(Theme.accent),
                            in: RoundedRectangle(
                                cornerRadius: Theme.rPanel,
                                style: .continuous
                            )
                        )
                        .contentShape(
                            RoundedRectangle(
                                cornerRadius: Theme.rPanel,
                                style: .continuous
                            )
                        )
                }
                .buttonStyle(.plain)
                .disabled(uploads.contains { $0.status == .uploading })
                .accessibilityHint("Selects one or more model, CAD, archive, or PDF files to upload")
            }

            if let fileImportError {
                Text(fileImportError)
                    .font(.footnote)
                    .foregroundStyle(Theme.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("File import error: \(fileImportError)")
            }

            if assets.isEmpty {
                Text("No model, CAD, archive, or PDF files are stored for this project yet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .planGlass(elevated: false)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(assets.enumerated()), id: \.element.id) { index, asset in
                        if index > 0 {
                            Divider().overlay(Theme.line)
                        }
                        fileRow(asset)
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                        .strokeBorder(Theme.line.opacity(0.62), lineWidth: 1)
                )
            }
        }
    }

    private func fileRow(_ asset: BambuAsset) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 4) {
                Button {
                    Task { await downloadAndShare(asset) }
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: asset.kind.workshopSymbol)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Theme.accentDeep)
                            .frame(width: 30)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(asset.filename)
                                .font(.body)
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(fileMetadata(asset))
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        if downloadingAssetId == asset.id {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Theme.accentDeep)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.accentDeep)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(downloadingAssetId != nil || deletingAssetId != nil)
                .accessibilityLabel(
                    downloadingAssetId == asset.id
                        ? "Downloading \(asset.filename)"
                        : "Download and share \(asset.filename), \(fileMetadata(asset))"
                )

                if !model.isDemoMode {
                    Button(role: .destructive) {
                        pendingDeleteAsset = asset
                    } label: {
                        if deletingAssetId == asset.id {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Theme.red)
                        } else {
                            Image(systemName: "trash")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.red)
                    .disabled(downloadingAssetId != nil || deletingAssetId != nil)
                    .accessibilityLabel(
                        deletingAssetId == asset.id
                            ? "Deleting \(asset.filename)"
                            : "Delete \(asset.filename)"
                    )
                }
            }

            if let failure = assetActionFailure, failure.assetId == asset.id {
                Text(failure.message)
                    .font(.footnote)
                    .foregroundStyle(Theme.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("File action error: \(failure.message)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var confirmingAssetDelete: Binding<Bool> {
        Binding(
            get: { pendingDeleteAsset != nil },
            set: { isPresented in
                if !isPresented { pendingDeleteAsset = nil }
            }
        )
    }

    private static let supportedImportTypes: [UTType] = {
        let extensions = [
            "stl", "3mf", "obj", "step", "stp", "iges", "igs", "f3d",
            "fcstd", "scad", "skp", "dae", "ply", "gcode", "zip", "rar", "7z",
        ]
        return [.threeDContent, .archive, .pdf]
            + extensions.compactMap { UTType(filenameExtension: $0) }
    }()
    private static let maximumUploadBytes = 250 * 1_024 * 1_024

    private func importFiles(_ result: Result<[URL], Error>) async {
        guard !model.isDemoMode else { return }
        let urls: [URL]
        switch result {
        case .success(let selected):
            urls = selected
        case .failure(let error):
            if (error as? CocoaError)?.code == .userCancelled { return }
            fileImportError = "Couldn't open the selected files. \(error.localizedDescription)"
            return
        }
        guard !urls.isEmpty else { return }

        fileImportError = nil
        var uploadedAny = false
        for url in urls {
            uploadedAny = await uploadFile(url) || uploadedAny
        }
        if uploadedAny {
            await load()
            onChanged()
            Haptics.success()
        }
    }

    private func uploadFile(_ url: URL) async -> Bool {
        let entryId = UUID()
        let displayName = BambuUI.safeFilename(
            url.lastPathComponent,
            fallback: "Bambu-upload"
        )
        uploads.append(UploadEntry(id: entryId, name: displayName))

        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
            let values = try url.resourceValues(
                forKeys: [.isRegularFileKey, .contentTypeKey, .fileSizeKey]
            )
            guard values.isRegularFile != false else {
                throw BambuFileImportError.notARegularFile
            }
            guard let fileSize = values.fileSize, fileSize > 0 else {
                throw BambuFileImportError.emptyFile
            }
            guard fileSize <= Self.maximumUploadBytes else {
                throw BambuFileImportError.tooLarge
            }
            let filename = BambuUI.safeFilename(
                url.lastPathComponent,
                fallback: "Bambu-upload"
            )
            _ = try await api.uploadBambuAssetFile(
                bambuProjectId: bambuId,
                sourceFileURL: url,
                filename: filename,
                mimeType: Self.mimeType(
                    forExtension: url.pathExtension,
                    contentType: values.contentType
                )
            ) { progress in
                Task { @MainActor in
                    setUploadProgress(entryId, progress)
                }
            }
            setUploadStatus(entryId, .done)
            scheduleUploadDismiss(entryId)
            return true
        } catch {
            NSLog(
                "[Workshop] Bambu manual file upload failed for %@: %@",
                displayName,
                String(describing: error)
            )
            setUploadStatus(
                entryId,
                .error,
                error: "Couldn't upload this file. \(error.localizedDescription)"
            )
            return false
        }
    }

    nonisolated private static func mimeType(
        forExtension pathExtension: String,
        contentType: UTType?
    ) -> String {
        switch pathExtension.lowercased() {
        case "3mf":
            "application/vnd.ms-package.3dmanufacturing-3dmodel+xml"
        case "stl":
            "model/stl"
        case "obj":
            "model/obj"
        case "step", "stp":
            "model/step"
        case "iges", "igs":
            "model/iges"
        case "zip":
            "application/zip"
        case "rar":
            "application/vnd.rar"
        case "7z":
            "application/x-7z-compressed"
        case "pdf":
            "application/pdf"
        default:
            contentType?.preferredMIMEType ?? "application/octet-stream"
        }
    }

    private func setUploadProgress(_ id: UUID, _ progress: Double) {
        guard let index = uploads.firstIndex(where: { $0.id == id }) else { return }
        uploads[index].progress = min(max(progress, 0), 1)
    }

    private func setUploadStatus(
        _ id: UUID,
        _ status: UploadEntry.Status,
        error: String? = nil
    ) {
        guard let index = uploads.firstIndex(where: { $0.id == id }) else { return }
        uploads[index].status = status
        uploads[index].progress = status == .done ? 1 : uploads[index].progress
        uploads[index].error = error
    }

    private func scheduleUploadDismiss(_ id: UUID) {
        Task {
            try? await Task.sleep(for: .seconds(2))
            uploads.removeAll { $0.id == id && $0.status == .done }
        }
    }

    private func section<Content: View>(
        _ title: String,
        count: Int? = nil,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Rail(title, count: count)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadFailure(_ message: String) -> some View {
        VStack(spacing: 10) {
            Text("Couldn't load this 3D project")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }
                .minimumHitTarget()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 80)
    }

    private func imageURLs(_ project: BambuProject) -> [URL] {
        project.workshopImageAssets.compactMap(imageAssetURL)
    }

    private func heroIndex(_ project: BambuProject, urls: [URL]) -> Int {
        guard let heroId = project.heroAssetId,
              let heroAsset = project.workshopImageAssets.first(where: { $0.id == heroId }),
              let heroURL = imageAssetURL(heroAsset),
              let index = urls.firstIndex(of: heroURL)
        else { return 0 }
        return index
    }

    private func imageAssetURL(_ asset: BambuAsset) -> URL? {
        guard asset.kind == .image else { return nil }
        guard let userKey = model.userKey else { return nil }
        return api.bambuAssetURL(assetId: asset.id, userKey: userKey)
    }

    private func fileMetadata(_ asset: BambuAsset) -> String {
        let type = asset.contentType.isEmpty
            ? asset.kind.workshopDisplayName
            : asset.contentType
        let size = ByteCountFormatter.string(
            fromByteCount: Int64(asset.sizeBytes),
            countStyle: .file
        )
        return "\(type) - \(size)"
    }

    private func load() async {
        loading = project == nil
        loadError = nil
        do {
            project = try await api.bambuProject(id: bambuId)
        } catch {
            loadError = error.localizedDescription
        }
        loading = false
    }

    private func downloadAndShare(_ asset: BambuAsset) async {
        guard downloadingAssetId == nil else { return }
        downloadingAssetId = asset.id
        assetActionFailure = nil
        defer { downloadingAssetId = nil }

        var failedDirectory: URL?
        do {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("Workshop-Bambu-Shares", isDirectory: true)
            let directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
            failedDirectory = directory
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let filename = BambuUI.safeFilename(
                asset.filename,
                fallback: "Bambu-asset-\(asset.id)"
            )
            let destination = directory.appendingPathComponent(filename, isDirectory: false)
            _ = try await api.downloadBambuAsset(id: asset.id, to: destination)
            sharedDirectoryURL = directory
            shareURL = IdentifiableURL(url: destination)
            failedDirectory = nil
        } catch {
            if let failedDirectory {
                do {
                    try FileManager.default.removeItem(at: failedDirectory)
                } catch where (error as? CocoaError)?.code == .fileNoSuchFile {
                    // The directory was never created, so there is nothing to clean up.
                } catch {
                    NSLog(
                        "[Workshop] Could not clean up failed Bambu download at %@: %@",
                        failedDirectory.path,
                        String(describing: error)
                    )
                }
            }
            NSLog(
                "[Workshop] Bambu asset download failed for id=%d: %@",
                asset.id,
                String(describing: error)
            )
            assetActionFailure = AssetActionFailure(
                assetId: asset.id,
                message: "Couldn't download this local file. \(error.localizedDescription)"
            )
        }
    }

    private func deleteAsset(_ asset: BambuAsset) async {
        guard !model.isDemoMode, deletingAssetId == nil else { return }
        pendingDeleteAsset = nil
        deletingAssetId = asset.id
        assetActionFailure = nil
        defer { deletingAssetId = nil }

        do {
            try await api.deleteBambuAsset(id: asset.id)
            await load()
            onChanged()
            Haptics.success()
        } catch {
            NSLog(
                "[Workshop] Bambu asset delete failed for id=%d: %@",
                asset.id,
                String(describing: error)
            )
            Haptics.error()
            assetActionFailure = AssetActionFailure(
                assetId: asset.id,
                message: "Couldn't delete this local file. \(error.localizedDescription)"
            )
        }
    }

    private func cleanupSharedFile() {
        guard let directory = sharedDirectoryURL else { return }
        sharedDirectoryURL = nil
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            NSLog(
                "[Workshop] Could not clean up shared Bambu file at %@: %@",
                directory.path,
                String(describing: error)
            )
        }
    }

    private func deleteProject() async {
        guard !model.isDemoMode else { return }
        deleting = true
        deleteError = nil
        do {
            try await api.deleteBambuProject(id: bambuId)
            Haptics.success()
            onChanged()
            dismiss()
        } catch {
            Haptics.error()
            deleting = false
            deleteError = "Couldn't delete this project or confirm removal of its files. \(error.localizedDescription)"
        }
    }
}

private struct AssetActionFailure {
    let assetId: Int
    let message: String
}

private enum BambuFileImportError: LocalizedError {
    case notARegularFile
    case emptyFile
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .notARegularFile:
            "The selected item is not a regular file."
        case .emptyFile:
            "The selected file is empty."
        case .tooLarge:
            "The selected file exceeds Workshop's 250 MB per-file limit."
        }
    }
}
