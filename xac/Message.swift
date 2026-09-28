import Foundation

enum MessageRole {
    case user
    case model
}

struct Message: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    var content: String
}
