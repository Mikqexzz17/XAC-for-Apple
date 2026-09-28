import Foundation

class Store {
    static let shared = Store()
    private let fileName = "agents.json"

    private let messagesFileName = "messages.json"

    private var fileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(fileName)
    }

    private var messagesFileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(messagesFileName)
    }

    func save(agents: [AgentRole]) {
        do {
            let data = try JSONEncoder().encode(agents)
            try data.write(to: fileURL)
            print("Successfully saved agents.")
        } catch {
            print("Failed to save agents: \(error)")
        }
    }

    func load() -> [AgentRole]? {
        do {
            let data = try Data(contentsOf: fileURL)
            let agents = try JSONDecoder().decode([AgentRole].self, from: data)
            print("Successfully loaded agents.")
            return agents
        } catch {
            print("Failed to load agents: \(error)")
            return nil
        }
    }

    func saveMessages(messages: [Message]) {
        do {
            let data = try JSONEncoder().encode(messages)
            try data.write(to: messagesFileURL)
            print("Successfully saved messages.")
        } catch {
            print("Failed to save messages: \(error)")
        }
    }

    func loadMessages() -> [Message]? {
        do {
            let data = try Data(contentsOf: messagesFileURL)
            let msgs = try JSONDecoder().decode([Message].self, from: data)
            print("Successfully loaded messages.")
            return msgs
        } catch {
            print("Failed to load messages: \(error)")
            return nil
        }
    }
}
