import Foundation
import LocalTodoDomain

extension VaultScanner {
    func requestRootMaterialization(into results: inout ScanResults) {
        do {
            try fileSystem.requestMaterialization(at: root)
        } catch {
            let message = "Unable to request vault download: \(error.localizedDescription)"
            results.markScanIncomplete(message)
            results.diagnostics.append(VaultDiagnostic(
                severity: .error,
                kind: .inputOutput,
                message: message
            ))
        }
    }

    func recordAvailability(at url: URL, path: VaultPath, results: inout ScanResults) -> Bool {
        switch fileSystem.availability(at: url) {
        case .available:
            return true
        case .downloading:
            requestMaterialization(at: url, path: path, results: &results)
            return false
        case let .unavailable(message):
            results.markUnavailable(path, state: .unavailable(message), message: message)
            return false
        case .missing:
            results.markUnavailable(path, state: .missing, message: "File disappeared during vault scan")
            return false
        }
    }

    private func requestMaterialization(at url: URL, path: VaultPath, results: inout ScanResults) {
        do {
            try fileSystem.requestMaterialization(at: url)
            results.markUnavailable(path, state: .downloading, message: "Waiting for file download")
        } catch {
            results.markUnavailable(
                path,
                state: .unavailable(error.localizedDescription),
                message: "Unable to request file download: \(error.localizedDescription)"
            )
        }
    }
}
