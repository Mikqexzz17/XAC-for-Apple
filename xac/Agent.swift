import Foundation

struct AgentRole: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var systemPrompt: String
    var modelURL: URL?
    var modelBookmarkData: Data?
}
