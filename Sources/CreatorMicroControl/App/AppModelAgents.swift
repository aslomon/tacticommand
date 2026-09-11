import CreatorMicroCore

extension AppModel {
    func startAgentRefresh() {
        guard agentTask == nil else { return }
        agentTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                agentSnapshot = await agentStore.refresh()
                await synchronizeLighting()
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    return
                }
            }
        }
    }
}
