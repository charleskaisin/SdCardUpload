import Foundation

enum AppPhase: Equatable {
    case waiting
    case ready
    case working
    case success
    case failure
}

enum WorkflowStep: Int, CaseIterable {
    case clean = 0
    case copy
    case verify
    case polish
    case inspect
    case eject

    var title: String {
        switch self {
        case .clean: return "Vider"
        case .copy: return "Copier"
        case .verify: return "Vérifier"
        case .polish: return "Nettoyer"
        case .inspect: return "Contrôler"
        case .eject: return "Éjecter"
        }
    }

    var symbol: String {
        switch self {
        case .clean: return "trash"
        case .copy: return "arrow.down.doc"
        case .verify: return "checkmark.shield"
        case .polish: return "sparkles"
        case .inspect: return "magnifyingglass"
        case .eject: return "eject"
        }
    }
}

struct CardDetails: Equatable {
    let name: String
    let sizeText: String
    let fileSystem: String
    let wholeDisk: String
    let mountPath: String
}

struct ToolResult {
    let status: Int32
    let output: String
    let timedOut: Bool
}

enum CardPrepError: LocalizedError {
    case message(String)
    case removableVolumePermission(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        case .removableVolumePermission(let text): return text
        }
    }

    var requiresAccessSettings: Bool {
        if case .removableVolumePermission = self { return true }
        return false
    }
}
