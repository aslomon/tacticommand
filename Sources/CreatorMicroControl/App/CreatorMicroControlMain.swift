import SwiftUI

@main
struct CreatorMicroControlMain: App {
    @NSApplicationDelegateAdaptor(CreatorMicroApplicationDelegate.self)
    private var applicationDelegate
    @State private var model: AppModel

    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        applicationDelegate.model = model
        model.start()
    }

    var body: some Scene {
        Settings {
            ConfigurationWindowView(model: model)
                .task { model.start() }
                .frame(width: 980, height: 680)
        }
    }
}
