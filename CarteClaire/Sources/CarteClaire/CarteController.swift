import AppKit
import Combine
import Darwin
import Foundation

final class CarteController: ObservableObject {
    static let volumeName = "CK"
    static let volumePath = "/Volumes/CK"

    @Published var phase: AppPhase = .waiting
    @Published var card: CardDetails?
    @Published var videoURL: URL?
    @Published var currentStep: Int = -1
    @Published var progress: Double?
    @Published var statusTitle = "Insérez une carte SD"
    @Published var statusDetail = "L’app attend une carte nommée CK."
    @Published var errorMessage = ""
    @Published var needsAccessHelp = false

    private let fileManager = FileManager.default
    private var detectionTimer: Timer?
    private var inspectionInProgress = false
    private var operationInProgress = false
    private var activeCardAccessURL: URL?

    init() {
        restoreCardAccess()
        restoreVideoSelection()
        detectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollForCard()
        }
        pollForCard()
    }

    deinit {
        detectionTimer?.invalidate()
        activeCardAccessURL?.stopAccessingSecurityScopedResource()
    }

    var canPrepare: Bool {
        guard card != nil, videoURL != nil, !operationInProgress else { return false }
        return phase == .ready || phase == .failure
    }

    var canEject: Bool {
        card != nil && !operationInProgress
    }

    var primaryButtonTitle: String {
        switch phase {
        case .waiting: return "En attente de la carte…"
        case .ready: return "Préparer la carte"
        case .working: return "Préparation en cours…"
        case .success: return "Insérez la carte suivante"
        case .failure: return card == nil ? "Insérez une nouvelle carte" : "Réessayer"
        }
    }

    func askToPrepare() {
        prepareConfirmed()
    }

    func requestCardAccess() {
        guard !operationInProgress else { return }

        let panel = NSOpenPanel()
        panel.title = "Donner accès à la carte CK"
        panel.message = "Sélectionnez la carte CK dans Volumes, puis cliquez sur Autoriser."
        panel.prompt = "Autoriser"
        panel.directoryURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let selected = panel.url else { return }
        guard selected.standardizedFileURL.path == Self.volumePath else {
            statusTitle = "Choisissez la carte CK"
            statusDetail = "La carte sélectionnée doit être /Volumes/CK."
            return
        }

        activeCardAccessURL?.stopAccessingSecurityScopedResource()
        _ = selected.startAccessingSecurityScopedResource()
        activeCardAccessURL = selected

        if let bookmark = try? selected.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(bookmark, forKey: "cardAccessBookmark")
        }

        needsAccessHelp = false
        phase = .ready
        statusTitle = "Accès accordé"
        statusDetail = "Nouvelle tentative…"
        prepareConfirmed()
    }

    private func restoreCardAccess() {
        guard let data = UserDefaults.standard.data(forKey: "cardAccessBookmark") else { return }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ), url.standardizedFileURL.path == Self.volumePath else { return }

        _ = url.startAccessingSecurityScopedResource()
        activeCardAccessURL = url

        if isStale,
           let refreshed = try? url.bookmarkData(
               options: .withSecurityScope,
               includingResourceValuesForKeys: nil,
               relativeTo: nil
           ) {
            UserDefaults.standard.set(refreshed, forKey: "cardAccessBookmark")
        }
    }

    func chooseVideo() {
        guard !operationInProgress else { return }

        let panel = NSOpenPanel()
        panel.title = "Choisissez la vidéo du projecteur"
        panel.prompt = "Choisir"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first

        if panel.runModal() == .OK, let selected = panel.url {
            videoURL = selected
            UserDefaults.standard.set(selected.path, forKey: "selectedVideoPath")
            if phase == .waiting {
                statusDetail = "Vidéo prête. Insérez une carte nommée CK."
            }
        }
    }

    func prepareConfirmed() {
        guard let selectedCard = card, let selectedVideo = videoURL, canPrepare else { return }

        operationInProgress = true
        phase = .working
        currentStep = 0
        progress = nil
        errorMessage = ""
        needsAccessHelp = false
        statusTitle = "Nettoyage de la carte"
        statusDetail = "Suppression de tous les fichiers, même invisibles…"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.runWorkflow(card: selectedCard, sourceVideo: selectedVideo)
        }
    }

    func ejectCurrentCard() {
        guard let selectedCard = card, canEject else { return }
        operationInProgress = true
        statusTitle = "Éjection…"
        statusDetail = "Patientez quelques secondes."
        progress = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let result = self.runTool(
                executable: "/usr/sbin/diskutil",
                arguments: ["eject", "force", selectedCard.wholeDisk],
                timeout: 90
            )

            DispatchQueue.main.async {
                self.operationInProgress = false
                if result.status == 0 {
                    self.card = nil
                    self.phase = .waiting
                    self.statusTitle = "Carte éjectée"
                    self.statusDetail = "Vous pouvez la retirer et insérer la suivante."
                } else {
                    self.phase = .failure
                    self.errorMessage = "Le Mac n’a pas réussi à éjecter la carte. Fermez les fenêtres du Finder et réessayez."
                    self.statusTitle = "Éjection impossible"
                    self.statusDetail = self.errorMessage
                }
            }
        }
    }

    private func restoreVideoSelection() {
        if let savedPath = UserDefaults.standard.string(forKey: "selectedVideoPath"),
           fileManager.fileExists(atPath: savedPath) {
            videoURL = URL(fileURLWithPath: savedPath)
            return
        }

        let downloads = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let defaultVideo = downloads.appendingPathComponent("love.mov")
        if fileManager.fileExists(atPath: defaultVideo.path) {
            videoURL = defaultVideo
        }
    }

    private func pollForCard() {
        guard !operationInProgress, !inspectionInProgress else { return }
        let mounted = fileManager.fileExists(atPath: Self.volumePath)

        if !mounted {
            card = nil
            if phase == .ready {
                phase = .waiting
                statusTitle = "Insérez une carte SD"
                statusDetail = "L’app attend une carte nommée CK."
            }
            return
        }

        guard card == nil else { return }
        inspectionInProgress = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let result = self.inspectMountedCard()
            DispatchQueue.main.async {
                self.inspectionInProgress = false
                switch result {
                case .success(let details):
                    self.card = details
                    self.phase = .ready
                    self.currentStep = -1
                    self.progress = 0
                    self.errorMessage = ""
                    self.needsAccessHelp = false
                    self.statusTitle = "Carte CK détectée"
                    self.statusDetail = "Tout est prêt. Appuyez sur le bouton pour commencer."
                case .failure(let error):
                    self.phase = .failure
                    self.errorMessage = error.localizedDescription
                    self.statusTitle = "Carte non utilisable"
                    self.statusDetail = error.localizedDescription
                }
            }
        }
    }

    private func inspectMountedCard() -> Result<CardDetails, Error> {
        let result = runTool(
            executable: "/usr/sbin/diskutil",
            arguments: ["info", Self.volumePath],
            timeout: 15
        )

        guard result.status == 0 else {
            return .failure(CardPrepError.message("Le Mac ne reconnaît pas correctement la carte CK."))
        }

        let mountPoint = value(after: "Mount Point:", in: result.output)
        let wholeDisk = value(after: "Part of Whole:", in: result.output)
        let internalValue = value(after: "Internal:", in: result.output)
        let location = value(after: "Device Location:", in: result.output)
        let fileSystem = value(after: "File System Personality:", in: result.output)

        guard mountPoint == Self.volumePath, !wholeDisk.isEmpty else {
            return .failure(CardPrepError.message("Impossible d’identifier cette carte en toute sécurité."))
        }

        guard internalValue == "No" || location == "External" else {
            return .failure(CardPrepError.message("Sécurité activée : CK ne semble pas être un support externe."))
        }

        let sizeText: String
        if let attributes = try? fileManager.attributesOfFileSystem(forPath: Self.volumePath),
           let size = attributes[.systemSize] as? NSNumber {
            sizeText = ByteCountFormatter.string(fromByteCount: size.int64Value, countStyle: .file)
        } else {
            sizeText = "taille inconnue"
        }

        return .success(CardDetails(
            name: Self.volumeName,
            sizeText: sizeText,
            fileSystem: fileSystem.isEmpty ? "format inconnu" : fileSystem,
            wholeDisk: wholeDisk,
            mountPath: Self.volumePath
        ))
    }

    private func runWorkflow(card: CardDetails, sourceVideo: URL) {
        do {
            guard fileManager.fileExists(atPath: card.mountPath) else {
                throw CardPrepError.message("La carte a été retirée avant le début de l’opération.")
            }
            guard fileManager.fileExists(atPath: sourceVideo.path) else {
                throw CardPrepError.message("La vidéo sélectionnée est introuvable.")
            }
            guard !sourceVideo.path.hasPrefix(card.mountPath + "/") else {
                throw CardPrepError.message("La vidéo source ne peut pas se trouver sur la carte qui sera vidée.")
            }

            let sourceSize = try fileSize(at: sourceVideo)
            guard sourceSize > 0 else {
                throw CardPrepError.message("La vidéo sélectionnée est vide.")
            }

            let destination = URL(fileURLWithPath: card.mountPath)
                .appendingPathComponent(sourceVideo.lastPathComponent)
            let spotlightMarker = URL(fileURLWithPath: card.mountPath)
                .appendingPathComponent(".metadata_never_index")
            let fseventsMarker = URL(fileURLWithPath: card.mountPath)
                .appendingPathComponent(".fseventsd")
            let trashMarker = URL(fileURLWithPath: card.mountPath)
                .appendingPathComponent(".Trashes")

            publish(step: .clean, title: "Carte remise à zéro", detail: "Arrêt de Spotlight et nettoyage des fichiers invisibles…", progress: nil)
            _ = runTool(
                executable: "/usr/bin/mdutil",
                arguments: ["-i", "off", card.mountPath],
                timeout: 12
            )
            _ = runTool(
                executable: "/usr/bin/mdutil",
                arguments: ["-X", card.mountPath],
                timeout: 12
            )
            try ensureRegularFile(at: spotlightMarker, description: "la protection Spotlight")
            try removeItems(on: card, keeping: [spotlightMarker])
            let emptyItems = try volumeItems(at: card.mountPath).filter {
                $0.standardizedFileURL.path != spotlightMarker.standardizedFileURL.path
            }
            guard emptyItems.isEmpty else {
                throw CardPrepError.message("La carte contient encore un élément après le nettoyage.")
            }

            try fileManager.createDirectory(at: fseventsMarker, withIntermediateDirectories: true)
            try ensureRegularFile(
                at: fseventsMarker.appendingPathComponent("no_log"),
                description: "la protection FSEvents"
            )
            try installTrashGuard(at: trashMarker, on: card)

            let freeSize = try availableSize(at: card.mountPath)
            guard sourceSize <= freeSize else {
                throw CardPrepError.message("La carte est trop petite pour contenir cette vidéo.")
            }

            publish(step: .copy, title: "Copie unique de la vidéo", detail: "0 %", progress: 0)
            let copyDuration = try copyWithProgress(
                source: sourceVideo,
                destination: destination,
                totalBytes: sourceSize
            )

            publish(step: .verify, title: "Vérification intégrale", detail: "Lecture de la copie sur la carte…", progress: nil)
            try verifyCopy(source: sourceVideo, destination: destination, copyDuration: copyDuration)

            publish(step: .polish, title: "Dernier coup de propre", detail: "Suppression des fichiers recréés par macOS…", progress: nil)
            try removeItems(on: card, keeping: [destination, spotlightMarker, fseventsMarker, trashMarker])

            let presyncResult = runTimedTool(
                executable: "/bin/sync",
                arguments: [],
                timeout: 180,
                label: "Synchronisation avant contrôle"
            )
            guard presyncResult.status == 0 else {
                throw CardPrepError.message("La synchronisation de la carte a échoué.")
            }

            try? fileManager.removeItem(at: fseventsMarker)
            try? fileManager.removeItem(at: spotlightMarker)
            try? fileManager.removeItem(at: trashMarker)
            try removeItems(on: card, keeping: [destination])

            publish(step: .inspect, title: "Contrôle final", detail: "La carte doit contenir exactement une vidéo.", progress: nil)
            let finalItems = try volumeItems(at: card.mountPath)
            guard finalItems.count == 1,
                  finalItems[0].standardizedFileURL.path == destination.standardizedFileURL.path else {
                throw CardPrepError.message("La carte contient encore un fichier indésirable.")
            }
            guard try fileSize(at: destination) == sourceSize else {
                throw CardPrepError.message("La taille de la vidéo finale est incorrecte.")
            }

            publish(step: .eject, title: "Synchronisation et éjection", detail: "La carte va être libérée en toute sécurité…", progress: nil)
            let syncResult = runTimedTool(
                executable: "/bin/sync",
                arguments: [],
                timeout: 180,
                label: "Synchronisation"
            )
            guard syncResult.status == 0 else {
                throw CardPrepError.message("La synchronisation de la carte a échoué.")
            }

            let ejectResult = runTimedTool(
                executable: "/usr/sbin/diskutil",
                arguments: ["eject", "force", card.wholeDisk],
                timeout: 90,
                label: "Éjection"
            )
            guard ejectResult.status == 0 else {
                throw CardPrepError.message("Le Mac n’a pas réussi à éjecter la carte.")
            }

            DispatchQueue.main.async {
                self.operationInProgress = false
                self.card = nil
                self.phase = .success
                self.currentStep = WorkflowStep.allCases.count
                self.progress = 1
                self.statusTitle = "Mission accomplie !"
                self.statusDetail = "La carte ne contient que \(sourceVideo.lastPathComponent). Retirez-la et insérez la suivante."
            }
        } catch {
            DispatchQueue.main.async {
                let needsAccess = self.requiresAccessSettings(for: error)
                let displayedError = needsAccess
                    ? "macOS n’a pas autorisé Carte Claire à modifier cette carte. Cliquez sur « Donner accès à CK… », choisissez CK, puis l’app réessaiera sans demander de mot de passe."
                    : error.localizedDescription
                self.operationInProgress = false
                self.phase = .failure
                self.progress = nil
                self.errorMessage = displayedError
                self.needsAccessHelp = needsAccess
                self.statusTitle = "Préparation interrompue"
                self.statusDetail = displayedError
            }
        }
    }

    private func volumeItems(at mountPath: String) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: mountPath),
            includingPropertiesForKeys: nil,
            options: []
        )
    }

    private func ensureRegularFile(at url: URL, description: String) throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard !isDirectory.boolValue else {
                throw CardPrepError.message("Impossible de créer \(description).")
            }
            return
        }

        guard fileManager.createFile(atPath: url.path, contents: Data()) else {
            throw removableVolumeAccessError()
        }
    }

    private func installTrashGuard(at trashMarker: URL, on card: CardDetails) throws {
        for _ in 0..<3 {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: trashMarker.path, isDirectory: &isDirectory) {
                if !isDirectory.boolValue { return }

                do {
                    try fileManager.removeItem(at: trashMarker)
                } catch {
                    try deleteWithoutPassword(paths: [trashMarker])
                }
            }

            if fileManager.createFile(atPath: trashMarker.path, contents: Data()) {
                return
            }
            Thread.sleep(forTimeInterval: 1)
        }

        throw removableVolumeAccessError()
    }

    private func removableVolumeAccessError() -> CardPrepError {
        CardPrepError.removableVolumePermission(
            "macOS n’a pas autorisé Carte Claire à modifier cette carte. Cliquez sur « Donner accès à CK… », choisissez CK, puis l’app réessaiera sans demander de mot de passe."
        )
    }

    private func requiresAccessSettings(for error: Error) -> Bool {
        if let cardError = error as? CardPrepError, cardError.requiresAccessSettings {
            return true
        }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain &&
            (nsError.code == NSFileReadNoPermissionError || nsError.code == NSFileWriteNoPermissionError) {
            return true
        }
        if nsError.domain == NSPOSIXErrorDomain &&
            (nsError.code == Int(EPERM) || nsError.code == Int(EACCES)) {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error,
           requiresAccessSettings(for: underlying) {
            return true
        }

        let diagnostic = nsError.localizedDescription.lowercased()
        return diagnostic.contains("operation not permitted") || diagnostic.contains("permission denied")
    }

    private func removeItems(on card: CardDetails, keeping keptURLs: [URL]) throws {
        let keptPaths = Set(keptURLs.map { $0.standardizedFileURL.path })
        var items = try volumeItems(at: card.mountPath)
        var protectedItems: [URL] = []

        for (index, item) in items.enumerated() {
            if keptPaths.contains(item.standardizedFileURL.path) { continue }
            let fraction = items.isEmpty ? 0 : Double(index) / Double(items.count)
            updateDetail("Suppression : \(item.lastPathComponent)", progress: fraction)
            do {
                try fileManager.removeItem(at: item)
            } catch {
                protectedItems.append(item)
            }
        }

        if !protectedItems.isEmpty {
            updateDetail("Nouvelle tentative de nettoyage…", progress: nil)
            try deleteWithoutPassword(paths: protectedItems)
        }

        items = try volumeItems(at: card.mountPath)
        let unexpected = items.filter { !keptPaths.contains($0.standardizedFileURL.path) }
        guard unexpected.isEmpty else {
            throw CardPrepError.message("macOS protège encore \(unexpected[0].lastPathComponent).")
        }
    }

    private func deleteWithoutPassword(paths: [URL]) throws {
        guard !paths.isEmpty else { return }

        var diagnostics = ""

        for item in paths {
            for attempt in 0..<3 {
                guard fileManager.fileExists(atPath: item.path) else { break }

                if attempt == 0 {
                    _ = runTool(executable: "/bin/chflags", arguments: ["-R", "nouchg,noschg", item.path], timeout: 30)
                    _ = runTool(executable: "/bin/chmod", arguments: ["-RN", item.path], timeout: 30)
                    _ = runTool(executable: "/bin/chmod", arguments: ["-R", "u+rwX", item.path], timeout: 30)
                    _ = runTool(executable: "/usr/bin/xattr", arguments: ["-cr", item.path], timeout: 30)
                }

                let result = runTool(
                    executable: "/bin/rm",
                    arguments: ["-rf", "--", item.path],
                    timeout: 90
                )
                diagnostics += "\n" + result.output
                if result.timedOut { break }
                if fileManager.fileExists(atPath: item.path) {
                    Thread.sleep(forTimeInterval: 0.7)
                }
            }
        }

        let remaining = paths.filter { fileManager.fileExists(atPath: $0.path) }
        guard remaining.isEmpty else {
            let diagnostic = diagnostics.lowercased()
            if diagnostic.contains("input/output error") || diagnostic.contains("i/o error") {
                throw CardPrepError.message("La carte a renvoyé une erreur de lecture/écriture. Essayez une autre carte ou un autre lecteur.")
            }
            throw removableVolumeAccessError()
        }
    }

    private func copyWithProgress(source: URL, destination: URL, totalBytes: Int64) throws -> TimeInterval {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")
        process.arguments = ["--inplace", source.path, destination.path]
        process.standardOutput = pipe
        process.standardError = pipe
        var environment = ProcessInfo.processInfo.environment
        environment["COPYFILE_DISABLE"] = "1"
        process.environment = environment

        do {
            try process.run()
        } catch {
            throw CardPrepError.message("Impossible de démarrer la copie.")
        }

        let started = Date()
        var lastProgress = started
        var previousSize: Int64 = 0

        while process.isRunning {
            Thread.sleep(forTimeInterval: 1)
            let currentSize = (try? fileSize(at: destination)) ?? previousSize
            if currentSize > previousSize {
                previousSize = currentSize
                lastProgress = Date()
            }

            let fraction = min(1, Double(currentSize) / Double(totalBytes))
            let elapsed = max(1, Date().timeIntervalSince(started))
            let speed = Double(currentSize) / elapsed
            let detail = "\(Int(fraction * 100)) %  •  \(formatBytes(currentSize)) / \(formatBytes(totalBytes))  •  \(formatSpeed(speed))"
            updateDetail(detail, progress: fraction)

            if Date().timeIntervalSince(lastProgress) >= 90 {
                process.terminate()
                Thread.sleep(forTimeInterval: 1)
                if process.isRunning {
                    Darwin.kill(process.processIdentifier, SIGKILL)
                }
                throw CardPrepError.message("La copie n’avance plus depuis 90 secondes. Essayez une autre carte, un autre adaptateur ou un autre lecteur.")
            }
        }

        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            let explanation = output.localizedCaseInsensitiveContains("input/output")
                ? "La carte ou le lecteur a renvoyé une erreur d’entrée/sortie."
                : "La copie de la vidéo a échoué."
            throw CardPrepError.message("\(explanation) Essayez une autre carte, un autre adaptateur ou un autre lecteur.")
        }

        guard try fileSize(at: destination) == totalBytes else {
            throw CardPrepError.message("La copie s’est terminée avec une taille incorrecte.")
        }

        updateDetail("100 %  •  copie unique terminée", progress: 1)
        return Date().timeIntervalSince(started)
    }

    private func verifyCopy(source: URL, destination: URL, copyDuration: TimeInterval) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/cmp")
        process.arguments = ["-s", source.path, destination.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            throw CardPrepError.message("Impossible de démarrer la vérification.")
        }

        let started = Date()
        let maximumDuration = max(600, min(3600, copyDuration * 5 + 120))

        while process.isRunning {
            Thread.sleep(forTimeInterval: 1)
            let elapsed = Date().timeIntervalSince(started)
            updateDetail("Lecture de la carte  •  \(formatDuration(elapsed)) écoulées", progress: nil)
            if elapsed >= maximumDuration {
                process.terminate()
                Thread.sleep(forTimeInterval: 1)
                if process.isRunning {
                    Darwin.kill(process.processIdentifier, SIGKILL)
                }
                throw CardPrepError.message("La vérification prend anormalement longtemps. La carte ou le lecteur semble bloqué.")
            }
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CardPrepError.message("La vidéo copiée ne correspond pas exactement à l’original.")
        }
        updateDetail("Copie vérifiée octet par octet.", progress: 1)
    }

    private func runTimedTool(executable: String, arguments: [String], timeout: TimeInterval, label: String) -> ToolResult {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return ToolResult(status: -1, output: error.localizedDescription, timedOut: false)
        }

        let started = Date()
        var timedOut = false
        while process.isRunning {
            Thread.sleep(forTimeInterval: 1)
            let elapsed = Date().timeIntervalSince(started)
            updateDetail("\(label)  •  \(formatDuration(elapsed)) écoulées", progress: nil)
            if elapsed >= timeout {
                timedOut = true
                process.terminate()
                Thread.sleep(forTimeInterval: 1)
                if process.isRunning {
                    Darwin.kill(process.processIdentifier, SIGKILL)
                }
                break
            }
        }

        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ToolResult(status: timedOut ? -1 : process.terminationStatus, output: output, timedOut: timedOut)
    }

    private func runTool(executable: String, arguments: [String], timeout: TimeInterval) -> ToolResult {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return ToolResult(status: -1, output: error.localizedDescription, timedOut: false)
        }

        let deadline = Date().addingTimeInterval(timeout)
        var timedOut = false
        while process.isRunning {
            if Date() >= deadline {
                timedOut = true
                process.terminate()
                Thread.sleep(forTimeInterval: 0.5)
                if process.isRunning {
                    Darwin.kill(process.processIdentifier, SIGKILL)
                }
                break
            }
            Thread.sleep(forTimeInterval: 0.1)
        }

        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ToolResult(status: timedOut ? -1 : process.terminationStatus, output: output, timedOut: timedOut)
    }

    private func fileSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let number = attributes[.size] as? NSNumber else {
            throw CardPrepError.message("Impossible de lire la taille de \(url.lastPathComponent).")
        }
        return number.int64Value
    }

    private func availableSize(at path: String) throws -> Int64 {
        let attributes = try fileManager.attributesOfFileSystem(forPath: path)
        guard let number = attributes[.systemFreeSize] as? NSNumber else {
            throw CardPrepError.message("Impossible de lire l’espace disponible sur la carte.")
        }
        return number.int64Value
    }

    private func value(after key: String, in text: String) -> String {
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(key) {
                return String(trimmed.dropFirst(key.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    private func publish(step: WorkflowStep, title: String, detail: String, progress: Double?) {
        DispatchQueue.main.async {
            self.currentStep = step.rawValue
            self.statusTitle = title
            self.statusDetail = detail
            self.progress = progress
        }
    }

    private func updateDetail(_ detail: String, progress: Double?) {
        DispatchQueue.main.async {
            self.statusDetail = detail
            self.progress = progress
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond > 0 else { return "0 Mo/s" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file) + "/s"
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
