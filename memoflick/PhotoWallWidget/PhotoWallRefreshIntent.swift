import AppIntents
import WidgetKit

@available(iOS 17.0, *)
struct PhotoWallRefreshIntent: AppIntent {
    static var title: LocalizedStringResource { "Refresh Photo Wall" }
    static var description: IntentDescription { "Refresh the widget photos." }

    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        WidgetPhotoStore.setPendingOpenSettings(true)
        return .result()
    }
}
