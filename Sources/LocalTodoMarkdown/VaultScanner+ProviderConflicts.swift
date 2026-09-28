import Foundation

extension VaultScanner {
    func scanProviderConflicts(into results: inout ScanResults) {
        do {
            for url in try fileSystem.providerConflictFiles(in: root) {
                scanProviderConflict(at: url, into: &results)
            }
        } catch {
            results.diagnostics.append(VaultDiagnostic(
                severity: .error,
                kind: .inputOutput,
                message: "Provider conflicts could not be inspected: \(error.localizedDescription)"
            ))
        }
    }

    private func scanProviderConflict(at url: URL, into results: inout ScanResults) {
        do {
            let alternatives = try fileSystem.unresolvedProviderVersions(at: url)
            guard !alternatives.isEmpty else { return }
            let path = relativePath(for: url)
            let current = try fileSystem.readCoordinated(at: url)
            results.providerConflicts[path] = VaultProviderConflict(
                path: path,
                currentContent: current,
                alternatives: alternatives
            )
        } catch {
            let message = "Provider conflict inspection failed for \(relativePath(for: url)): "
                + error.localizedDescription
            results.diagnostics.append(VaultDiagnostic(
                severity: .error,
                kind: .inputOutput,
                message: message
            ))
        }
    }

    private func relativePath(for url: URL) -> String {
        String(url.standardizedFileURL.path.dropFirst(root.path.count + 1))
    }
}
