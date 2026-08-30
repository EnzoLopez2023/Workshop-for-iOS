import SwiftUI
import NintekKit

/// Imports a public 3D project or edits metadata for an existing local import.
struct BambuProjectFormView: View {
    let api: WorkshopAPI
    let bambuId: Int?
    let onSaved: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var sourceURL = ""
    @State private var title = ""
    @State private var description = ""
    @State private var creatorName = ""
    @State private var licenseName = ""
    @State private var analysis: BambuAnalysisResult?
    @State private var analyzedURL: String?
    @State private var lastAppliedAnalysis: BambuAnalysisResult?
    @State private var existingProject: BambuProject?

    @State private var loading: Bool
    @State private var loadError: String?
    @State private var analyzing = false
    @State private var analysisError: String?
    @State private var saving = false
    @State private var saveError: String?
    @State private var completedProjectId: Int?
    @State private var completedWarnings: [String] = []

    private var editing: Bool { bambuId != nil }

    init(api: WorkshopAPI, bambuId: Int?, onSaved: @escaping (Int) -> Void) {
        self.api = api
        self.bambuId = bambuId
        self.onSaved = onSaved
        _loading = State(initialValue: bambuId != nil)
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loadError {
                    loadFailure(loadError)
                } else if let completedProjectId {
                    importCompletion(projectId: completedProjectId)
                } else {
                    form
                }
            }
            .boardBackground()
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let completedProjectId {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Open Project") {
                            finishImport(projectId: completedProjectId)
                        }
                        .fontWeight(.semibold)
                    }
                    .boardToolbarItem()
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .disabled(saving)
                    }
                    .boardToolbarItem()
                    ToolbarItem(placement: .confirmationAction) {
                        Button(saveButtonLabel) {
                            Task { await save() }
                        }
                        .disabled(!canSave)
                    }
                    .boardToolbarItem()
                }
            }
            .task {
                if editing { await loadExisting() }
            }
            .interactiveDismissDisabled(saving || completedProjectId != nil)
        }
    }

    private var navigationTitle: String {
        if completedProjectId != nil { return "Import Complete" }
        return editing ? "Edit 3D Project" : "Import 3D Project"
    }

    private var saveButtonLabel: String {
        if saving { return editing ? "Saving..." : "Importing..." }
        return editing ? "Save" : "Import"
    }

    private var canSave: Bool {
        guard !saving, !analyzing,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return false }
        if editing { return existingProject != nil }
        return analysis != nil && analyzedURL == normalizedSourceURL
    }

    private var normalizedSourceURL: String {
        sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var form: some View {
        List {
            if editing, let project = existingProject {
                existingSourceSection(project)
            } else {
                importSourceSection
                if let analysis {
                    analysisSummary(analysis)
                    analysisManifest(analysis)
                    warningSection(
                        title: "Page Warnings",
                        warnings: BambuUI.uniqueWarnings(analysis.warnings)
                    )
                }
                providerCapabilitiesSection
            }

            Section("Project Details") {
                TextField("Title", text: $title)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...8)
                TextField("Creator", text: $creatorName)
                TextField("License", text: $licenseName)
            }

            if editing, let project = existingProject {
                warningSection(
                    title: "Import Notes",
                    warnings: BambuUI.uniqueWarnings(project.importWarnings)
                )
                storedFilesSection(project)
            }

            if saving {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(Theme.accentDeep)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(editing ? "Saving metadata" : "Importing public files")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(editing
                                 ? "The stored images and files are unchanged."
                                 : "Workshop is reading the page again and downloading every anonymously accessible image and file. Large imports can take a few minutes.")
                                .font(.footnote)
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            if let saveError {
                Section {
                    errorText(saveError)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(PlanCanvasBackground())
        .environment(\.defaultMinListRowHeight, 50)
        .disabled(saving)
        .onChange(of: sourceURL) { _, _ in
            guard !editing, analyzedURL != normalizedSourceURL else { return }
            analysis = nil
            analyzedURL = nil
            analysisError = nil
        }
    }

    private var importSourceSection: some View {
        Section {
            TextField("Public MakerWorld, Thingiverse, or Printables URL", text: $sourceURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                Task { await analyze() }
            } label: {
                HStack(spacing: 10) {
                    if analyzing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    Text(analyzing ? "Reading the page..." : "Read the page")
                }
            }
            .disabled(analyzing || normalizedSourceURL.isEmpty)

            if let analysisError {
                errorText(analysisError)
            }
        } header: {
            Text("Public Project URL")
        } footer: {
            Text("Workshop previews the public page first. Import reads it again, then stores every image and model file the provider allows anonymous visitors to download.")
        }
    }

    private func existingSourceSection(_ project: BambuProject) -> some View {
        Section {
            LabeledContent("Provider", value: project.sourceSite.workshopDisplayName)
            if let modelId = project.sourceModelId, !modelId.isEmpty {
                LabeledContent("Model ID", value: modelId)
            }
            LabeledContent("Images", value: project.imageCount.formatted())
            LabeledContent("Files", value: project.fileCount.formatted())
            if let source = BambuUI.httpURL(project.sourceUrl) {
                Link("Open original project page", destination: source)
            }
        } header: {
            Text("Imported Source")
        } footer: {
            Text("Editing changes title, description, creator, and license only. The source URL and locally stored files are not reimported.")
        }
    }

    private func analysisSummary(_ result: BambuAnalysisResult) -> some View {
        Section("Page Preview") {
            if let previewURL = BambuUI.httpURL(result.previewImageUrl) {
                Color.clear
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay {
                        AuthImage(url: previewURL, contentMode: .fill, placeholderSymbol: "cube.fill")
                            .clipped()
                            .allowsHitTesting(false)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous))
                    .accessibilityLabel("Preview image for \(result.title)")
            }
            LabeledContent("Provider", value: result.sourceSite.workshopDisplayName)
            if let modelId = result.sourceModelId, !modelId.isEmpty {
                LabeledContent("Model ID", value: modelId)
            }
            LabeledContent("Images found", value: result.imageCount.formatted())
            LabeledContent("Files found", value: result.fileCount.formatted())
        }
    }

    private func analysisManifest(_ result: BambuAnalysisResult) -> some View {
        Section {
            if result.files.isEmpty {
                Text("No anonymously downloadable model or CAD files were found.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(Array(result.files.enumerated()), id: \.offset) { _, file in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: file.kind.workshopSymbol)
                            .foregroundStyle(Theme.accentDeep)
                            .frame(width: 24, height: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(file.filename)
                                .font(.body)
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(file.kind.workshopDisplayName)
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        } header: {
            Text("File Manifest")
        } footer: {
            Text("This is the complete manifest visible before import. Provider restrictions can still prevent individual downloads; Workshop preserves those filenames in import notes.")
        }
    }

    private var providerCapabilitiesSection: some View {
        Section("Provider Access") {
            ProviderCapabilityRow(
                provider: "Printables",
                text: "Copies public metadata, all source images, and all public STL, 3MF, CAD, and other files."
            )
            ProviderCapabilityRow(
                provider: "MakerWorld",
                text: "Copies public metadata and discoverable images. For protected originals, sign in on MakerWorld, download the files there, then use Add Files from the imported project. Workshop never asks for MakerWorld credentials or cookies."
            )
            ProviderCapabilityRow(
                provider: "Thingiverse",
                text: "Complete metadata, images, and files require an official token connected in More > Provider Connections or a shared Workshop server token. Without one, Workshop may create a minimal project and keeps a durable warning."
            )
        }
    }

    @ViewBuilder
    private func warningSection(title: String, warnings: [String]) -> some View {
        if !warnings.isEmpty {
            Section(title) {
                ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                    warningRow(warning)
                }
            }
        }
    }

    @ViewBuilder
    private func storedFilesSection(_ project: BambuProject) -> some View {
        if !project.workshopFileAssets.isEmpty {
            Section {
                ForEach(project.workshopFileAssets) { asset in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: asset.kind.workshopSymbol)
                            .foregroundStyle(Theme.accentDeep)
                            .frame(width: 24, height: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(asset.filename)
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(asset.contentType.isEmpty
                                 ? asset.kind.workshopDisplayName
                                 : asset.contentType)
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("Stored Files")
            } footer: {
                Text("Use the project detail screen to add, download, share, or remove local copies.")
            }
        }
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
            Button("Retry") { Task { await loadExisting() } }
                .minimumHitTarget()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func importCompletion(projectId: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(Theme.green)
                    Text("Project imported with notes")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("The project and every available local file are saved. These provider notes stay with the project so missing downloads are never hidden.")
                        .font(.body)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Rail("Import Notes", count: completedWarnings.count)
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(completedWarnings.enumerated()), id: \.offset) { _, warning in
                            warningRow(warning)
                        }
                    }
                    .padding(16)
                    .planGlass(elevated: false)
                }

                Button {
                    finishImport(projectId: projectId)
                } label: {
                    Label("Open Imported Project", systemImage: "arrow.right")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            Theme.accentDeep,
                            in: RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
            .contentColumn()
            .padding(20)
        }
    }

    private func warningRow(_ warning: String) -> some View {
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

    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(Theme.red)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Error: \(message)")
    }

    private func analyze() async {
        let requestedURL = normalizedSourceURL
        guard BambuUI.httpURL(requestedURL) != nil else {
            analysisError = "Enter a complete public http or https URL."
            return
        }

        analyzing = true
        analysisError = nil
        analysis = nil
        defer { analyzing = false }

        do {
            let result = try await api.analyzeBambuURL(requestedURL)
            guard normalizedSourceURL == requestedURL else { return }
            let previous = lastAppliedAnalysis
            analysis = result
            analyzedURL = requestedURL
            if shouldApplyAnalysisValue(title, previous: previous?.title) {
                title = result.title
            }
            if shouldApplyAnalysisValue(description, previous: previous?.description) {
                description = result.description
            }
            if shouldApplyAnalysisValue(creatorName, previous: previous?.creatorName) {
                creatorName = result.creatorName ?? ""
            }
            if shouldApplyAnalysisValue(licenseName, previous: previous?.licenseName) {
                licenseName = result.licenseName ?? ""
            }
            lastAppliedAnalysis = result
        } catch {
            guard normalizedSourceURL == requestedURL else { return }
            analysisError = "Couldn't read this public project page. \(error.localizedDescription)"
        }
    }

    private func shouldApplyAnalysisValue(_ current: String, previous: String?) -> Bool {
        if current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return previous.map { current == $0 } ?? false
    }

    private func loadExisting() async {
        guard let bambuId else { return }
        loading = true
        loadError = nil
        do {
            let project = try await api.bambuProject(id: bambuId)
            existingProject = project
            sourceURL = project.sourceUrl
            title = project.title
            description = project.description ?? ""
            creatorName = project.creatorName ?? ""
            licenseName = project.licenseName ?? ""
        } catch {
            loadError = error.localizedDescription
        }
        loading = false
    }

    private func save() async {
        guard canSave else { return }
        saving = true
        saveError = nil
        defer { saving = false }

        let input = BambuProjectInput(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceUrl: editing ? (existingProject?.sourceUrl ?? sourceURL) : normalizedSourceURL,
            description: optional(description),
            creatorName: optional(creatorName),
            licenseName: optional(licenseName)
        )

        do {
            if let bambuId {
                let project = try await api.updateBambuProject(id: bambuId, input)
                Haptics.success()
                onSaved(project.id)
                dismiss()
            } else {
                let result = try await api.createBambuProject(input)
                let warnings = BambuUI.uniqueWarnings(
                    result.warnings + result.project.importWarnings
                )
                Haptics.success()
                if warnings.isEmpty {
                    onSaved(result.project.id)
                    dismiss()
                } else {
                    completedWarnings = warnings
                    completedProjectId = result.project.id
                }
            }
        } catch {
            Haptics.error()
            saveError = editing
                ? "Couldn't save project metadata. \(error.localizedDescription)"
                : "Couldn't finish the import. No success was confirmed; check your connection before trying again. \(error.localizedDescription)"
        }
    }

    private func finishImport(projectId: Int) {
        onSaved(projectId)
        dismiss()
    }

    private func optional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct ProviderCapabilityRow: View {
    let provider: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(provider)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}
