import Foundation

final class MobileVaultPresenter: NSObject, NSFilePresenter, @unchecked Sendable {
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue
    private let onChange: @Sendable () -> Void

    init(rootURL: URL, onChange: @escaping @Sendable () -> Void) {
        presentedItemURL = rootURL
        self.onChange = onChange
        presentedItemOperationQueue = OperationQueue()
        presentedItemOperationQueue.maxConcurrentOperationCount = 1
        presentedItemOperationQueue.qualityOfService = .utility
    }

    func presentedItemDidChange() {
        onChange()
    }

    func presentedSubitemDidAppear(at _: URL) {
        onChange()
    }

    func presentedSubitemDidChange(at _: URL) {
        onChange()
    }

    func presentedSubitem(at _: URL, didMoveTo _: URL) {
        onChange()
    }

    func presentedSubitemDidDisappear(at _: URL) {
        onChange()
    }
}
