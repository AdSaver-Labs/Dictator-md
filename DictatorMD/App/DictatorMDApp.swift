import AppKit

@main
enum DictatorMDMain {
    private static var appDelegate: AppDelegate?
    private static var singleInstanceCoordinator: SingleInstanceCoordinator?

    static func main() {
        guard let coordinator = SingleInstanceCoordinator() else {
            SingleInstanceCoordinator.activateExistingInstance()
            return
        }
        singleInstanceCoordinator = coordinator

        let app = NSApplication.shared
        let delegate = AppDelegate()
        appDelegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
