import BitChordCore
import Downloads
import NetworkLibrary
import SwiftUI
import UniformTypeIdentifiers

/// The Downloads folder (and the Local Music folder): ports ui/screens/LocalMusicScreen.kt as
/// MainActivity.kt placed it for `local:downloads` and `local:all`.
///
/// The page is a snapshot of the folder, taken again whenever the record of what's on disk changes
/// — a track saved or deleted while it is open changes counts and rows in three tabs at once.
struct DownloadsScreen: View {
    /// Which folder. The shell routes `.downloads` here with the Downloads folder and `.localMusic`
    /// with Local Music (see `AppRoute.downloads` / `.localMusic`).
    var folder: LocalFolder = .downloads

    init(folder: LocalFolder = .downloads) {
        self.folder = folder
    }

    @Environment(AppModel.self) private var model
    @State private var songs: [Song] = []
    @State private var collections: [DownloadedCollection] = []
    @State private var loaded = false
    @State private var importing = false
    @State private var askedToImport = false

    var body: some View {
        let context = DownloadsContext.shared(for: model)
        let service = context.service
        let isDownloads = folder == .downloads
        LocalMusicView(
            title: folder.title,
            browseId: folder.browseId,
            songs: songs,
            collections: collections,
            isDownloads: isDownloads,
            emptyMessage: folder.emptyMessage,
            isLoading: !loaded,
            onDelete: isDownloads
                ? { chosen in service.delete(chosen.map(\.videoId)) }
                : { chosen in Task { await model.localFolderSync.deleteFromFolder(chosen.map(\.videoId)) } },
            onUpload: isDownloads && service.canUploadToWebDAV ? { chosen in Task { await context.upload(chosen) } } : nil,
            isDownloaded: { service.isDownloaded($0) }
        )
        .navigationTitle(folder.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: service.libraryVersion) {
            // The first listing is immediate. Later ones wait for the changes to pause: a folder
            // scan adds tracks one after another, and relisting thousands of rows for each would
            // keep the list from scrolling.
            if loaded {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
            }
            let listed = await service.songs(in: folder)
            // A newer change has started its own listing; this one's rows are already stale.
            guard !Task.isCancelled else { return }
            songs = listed
            // Only the Downloads folder has releases behind it: Local Music is files this app never
            // asked for, so there is nothing on record about how they were grouped.
            collections = isDownloads ? service.collections(among: listed) : []
            loaded = true
            // Android asked for the storage permission when Local Music was opened without it. The
            // iOS equivalent of "let the app see your music" is picking the folder in Files: asked
            // once per visit, and only while no folder is set or the one that was set is gone.
            // Once there is a folder nothing is asked again; the app watches it by itself.
            if folder == .localMusic, !askedToImport, LocalMusicFolder.resolve() == nil {
                askedToImport = true
                importing = true
            }
            #if DEBUG
            openDebugTargets()
            #endif
        }
        .localMusicFileImporter(isPresented: $importing)
        .webDavConflictPrompt(context)
        // A container: without this the screen identifier lands on every child and hides theirs.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.downloads.\(folder.rawValue)")
    }

    #if DEBUG
    /// `-downloadsOpen` targets that act on the page (see ``DownloadsDemoService``).
    private func openDebugTargets() {
        guard folder == .downloads else { return }
        let router = model.router
        if DownloadsDemoService.take("manager") { router.present(.downloadManager) }
        if DownloadsDemoService.take("smb") { router.open(.networkLibrary(.smb)) }
        if DownloadsDemoService.take("webdav") { router.open(.networkLibrary(.webDAV)) }
        if DownloadsDemoService.take("local") { router.open(AppRoute.browse(LocalBrowseID.all)) }
    }
    #endif
}

extension View {
    /// The Files picker that names the Local Music folder (PORTING Q8's MediaStore replacement): one
    /// folder, chosen once and then watched for changes by `LocalFolderSync`.
    func localMusicFileImporter(isPresented: Binding<Bool>) -> some View {
        modifier(LocalMusicFileImporter(isPresented: isPresented))
    }

    /// Asks what to do when a WebDAV upload finds the name already taken (WebDavConflictAlert).
    func webDavConflictPrompt(_ context: DownloadsContext) -> some View {
        modifier(WebDavConflictPromptModifier(context: context))
    }
}

private struct LocalMusicFileImporter: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content.fileImporter(isPresented: $isPresented, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let folder = urls.first else { return }
            model.localFolderSync.choose(folder)
        }
    }
}

private struct WebDavConflictPromptModifier: ViewModifier {
    @Bindable var context: DownloadsContext

    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(
            get: { context.conflict != nil },
            // Dismissing without an answer is a skip, as the Android dialog's dismiss was.
            set: { if !$0, context.conflict != nil { context.resolveConflict(.skip) } }
        )) {
            if let conflict = context.conflict {
                WebDavConflictPrompt(fileName: conflict.fileName,
                                     showApplyToAll: conflict.remaining > 0,
                                     applyToAll: $context.applyToAll,
                                     onChoose: { context.resolveConflict($0) })
                    .presentationDetents([.height(conflict.remaining > 0 ? 330 : 280)])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

/// AccountAlerts.kt's WebDavConflictAlert. A system alert can't carry the "Apply to all" box, so
/// the same title, message, three answers and box sit in a short sheet.
struct WebDavConflictPrompt: View {
    let fileName: String
    let showApplyToAll: Bool
    @Binding var applyToAll: Bool
    let onChoose: (WebDavUploads.Choice) -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(L10n.webdavConflictTitle(fileName))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(L10n.webdavConflictMessage)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 14)
            Divider()
            choice(L10n.webdavKeepBoth, emphasised: true, identifier: "webdav.keepBoth") { onChoose(.keepBoth) }
            Divider()
            choice(L10n.webdavOverwrite, identifier: "webdav.overwrite") { onChoose(.overwrite) }
            Divider()
            choice(L10n.webdavSkip, identifier: "webdav.skip") { onChoose(.skip) }
            if showApplyToAll {
                Divider()
                Toggle(L10n.webdavApplyToAll, isOn: $applyToAll)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .accessibilityIdentifier("webdav.applyToAll")
            }
            Spacer(minLength: 0)
        }
        .environment(\.layoutDirection, LanguageBundle.layoutDirection)
    }

    private func choice(_ label: String, emphasised: Bool = false, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(emphasised ? .body.weight(.semibold) : .body)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .accessibilityIdentifier(identifier)
    }
}
