import Foundation

struct AgentRole: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var systemPrompt: String
    var modelURL: URL?
}
