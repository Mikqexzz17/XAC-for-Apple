import Foundation

enum MessageRole: String, Codable {
    case user
    case model
}

struct Message: Identifiable, Equatable, Codable {
    var id = UUID()
    let role: MessageRole
    var content: String
    var senderName: String?
}
