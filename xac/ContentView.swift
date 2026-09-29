//
//  ContentView.swift
//  xac
//
//  Created by Pedro Cuenca on April 2023
//  Based on code by Cyril Zakka from https://github.com/cyrilzakka/pen
//

import SwiftUI
import Generation
import Models

enum ModelState: Equatable {
    case noModel
    case loading
    case ready(Double?)
    case generating(Double)
    case failed(String)
}

struct ContentView: View {

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var config = GenerationConfig(maxNewTokens: 20)
    @State private var prompt = "Write a poem about Valencia\n"
    @State private var modelURL: URL? = nil
    @State private var languageModel: LanguageModel? = nil

    @State private var isSettingsPresented = false
    @State private var isFirstLaunch = true

    @State private var status: ModelState = .noModel
    @State private var outputText: AttributedString = ""
    @State private var messages: [Message] = []
    @State private var agents: [AgentRole] = [AgentRole(name: "Default Agent", systemPrompt: "You are a helpful assistant.", modelURL: nil)]
    @State private var currentAgentName: String = ""

    @Binding var clearTriggered: Bool

    func modelDidChange() {
        // Keeping for backward compatibility with single model flow if needed,
        // but now primarily driven sequentially during run().
    }

    func clear() {
        outputText = ""
        messages = []
    }

    func run() {
        guard !agents.isEmpty else {
            status = .failed("No agents configured")
            return
        }
        guard !prompt.isEmpty else { return }

        let userMessage = prompt
        messages.append(Message(role: .user, content: userMessage))
        prompt = ""

        Task.init {
            var fullHistory = messages.map { $0.content }.joined(separator: "\n")

            for agent in agents {
                await MainActor.run { self.currentAgentName = agent.name }
                guard let url = agent.modelURL else {
                    await MainActor.run { status = .failed("Missing model for \(agent.name)") }
                    return
                }

                await MainActor.run { status = .loading }

                do {
                    // Load the model for the current agent
                    print("Loading model for \(agent.name)...")
                    let activeModel = try await ModelLoader.load(url: url)
                    await MainActor.run { self.languageModel = activeModel }

                    if let newConfig = activeModel.defaultGenerationConfig {
                        let maxNewTokens = self.config.maxNewTokens
                        await MainActor.run {
                            self.config = newConfig
                            self.config.maxNewTokens = min(maxNewTokens, activeModel.maxContextLength)
                        }
                    }

                    // Add UI bubble for this agent
                    let currentAgentName = agent.name
                    let modelMessageIndex = await MainActor.run { () -> Int in
                        messages.append(Message(role: .model, content: "", senderName: currentAgentName))
                        return messages.count - 1
                    }

                    let contextPrompt = agent.systemPrompt + "\n" + fullHistory

                    @Sendable func showOutput(currentGeneration: String, progress: Double, completedTokensPerSecond: Double? = nil) {
                        Task { @MainActor in
                            var response = currentGeneration.deletingPrefix("<s> ")
                            if response.count > contextPrompt.count {
                                response = String(response.dropFirst(contextPrompt.count)).replacingOccurrences(of: "\\n", with: "\n")
                            }

                            messages[modelMessageIndex].content = response
                            outputText = AttributedString(response) // Sync for copy button

                            if let tps = completedTokensPerSecond {
                                status = .ready(tps)
                            } else {
                                status = .generating(progress)
                            }
                        }
                    }

                    await MainActor.run { status = .generating(0) }
                    var tokensReceived = 0
                    let begin = Date()

                    let output = try await activeModel.generate(config: config, prompt: contextPrompt) { inProgressGeneration in
                        tokensReceived += 1
                        showOutput(currentGeneration: inProgressGeneration, progress: Double(tokensReceived)/Double(config.maxNewTokens))
                    }

                    let completionTime = Date().timeIntervalSince(begin)
                    let tokensPerSecond = Double(tokensReceived) / completionTime

                    // Safely format the final output logic to capture directly
                    var finalResponse = output.deletingPrefix("<s> ")
                    if finalResponse.count > contextPrompt.count {
                        finalResponse = String(finalResponse.dropFirst(contextPrompt.count)).replacingOccurrences(of: "\\n", with: "\n")
                    }

                    showOutput(currentGeneration: output, progress: 1, completedTokensPerSecond: tokensPerSecond)

                    // Append this agent's response to the full history so the next agent can see it securely on background thread
                    fullHistory += "\n[\(agent.name)]:\n" + finalResponse

                    // Release the model from memory before loading the next one
                    print("Releasing model for \(agent.name)")
                    await MainActor.run { self.languageModel = nil }

                } catch {
                    print("Error \(error)")
                    await MainActor.run { status = .failed("\(error)") }
                    return // Stop the chain if an agent fails
                }
            }
        }
    }

    @ViewBuilder
    var runButton: some View {
        switch status {
        case .noModel:
            EmptyView()
        case .loading:
            Text("> [\(currentAgentName)] Thinking...")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.green)
                .padding(.trailing, 6)
        case .ready, .failed:
            Button(action: run) { Label("Run", systemImage: "play.fill") }
                .keyboardShortcut("R")
        case .generating(let progress):
            ProgressView(value: progress).controlSize(.small).progressViewStyle(.circular).padding(.trailing, 6)
        }
    }

    var chatView: some View {
        GeometryReader { geometry in
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            HStack {
                                if message.role == .user {
                                    Spacer()
                                }

                                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                                    if let senderName = message.senderName {
                                        Text(senderName)
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    Text(LocalizedStringKey(message.content))
                                        .font(.system(.body, design: .monospaced))
                                        .padding()
                                        .background(message.role == .user ? Color.blue.opacity(0.2) : Color(red: 0.1, green: 0.1, blue: 0.15))
                                        .cornerRadius(12)
                                        .textSelection(.enabled)
                                }
                                .frame(maxWidth: geometry.size.width * 0.8, alignment: message.role == .user ? .trailing : .leading)
                                .contextMenu {
                                    Button(action: {
                                        if let index = messages.firstIndex(where: { $0.id == message.id }) {
                                            prompt = messages[index].content
                                        }
                                    }) {
                                        Label("Edit / Retry", systemImage: "pencil")
                                    }

                                    Button(role: .destructive, action: {
                                        if let index = messages.firstIndex(where: { $0.id == message.id }) {
                                            messages.remove(at: index)
                                        }
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }

                                if message.role == .model {
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: clearTriggered) { _, _ in
                    clear()
                }

                // Quick Prompts / Snippets
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        let snippets = ["Explain this code", "Optimize this algorithm", "Find security bugs", "Write a unit test"]
                        ForEach(snippets, id: \.self) { snippet in
                            Button(action: {
                                if prompt.isEmpty {
                                    prompt = snippet + ":\n"
                                } else {
                                    prompt += "\n" + snippet + ":\n"
                                }
                            }) {
                                Text(snippet)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 4)

                // Bottom Input Bar
                HStack {
                    TextField("Message...", text: $prompt)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    Button(action: run) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(prompt.isEmpty || status == .loading || String(describing: status).starts(with: "generating") ? .gray : .blue)
                    }
                    .disabled(prompt.isEmpty || status == .loading || String(describing: status).starts(with: "generating"))
                    .padding(.trailing)
                }
                .padding(.bottom)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        runButton

                        let exportText = messages.map { msg in
                            let role = msg.role == .user ? "User" : (msg.senderName ?? "AI")
                            return "[\(role)]\n\(msg.content)"
                        }.joined(separator: "\n\n")

                        ShareLink(item: exportText) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .disabled(messages.isEmpty)

                        Button(action: {
                            #if os(iOS)
                            UIPasteboard.general.string = String(outputText.characters)
                            #elseif os(macOS)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(String(outputText.characters), forType: .string)
                            #endif
                        }) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .disabled(outputText.characters.isEmpty)
                    }
                }
            }
        }
        .navigationTitle("Language Model Tester")
    }

    var regularView: some View {
        NavigationSplitView {
            VStack {
                ControlView(prompt: prompt, config: $config, model: $languageModel, agents: $agents)
                StatusView(status: $status)
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            chatView
        }
    }

#if os(iOS)
    var compactView: some View {
        NavigationView {
            VStack {
                chatView
                StatusView(status: $status)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gear") {
                        isSettingsPresented = true
                    }
                }
            }
        }
        .onAppear {
            if isFirstLaunch {
                isSettingsPresented = true
                isFirstLaunch = false
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            NavigationView {
                VStack {
                    ControlView(prompt: prompt, config: $config, model: $languageModel, agents: $agents)
                    StatusView(status: $status)
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isSettingsPresented = false
                        }
                    }
                }
            }
        }
    }
#endif

    var body: some View {
        TabView {
            Group {
#if os(iOS)
                if horizontalSizeClass == .compact && (verticalSizeClass == .compact || verticalSizeClass == .regular) {
                    compactView
                } else {
                    regularView
                }
#else
                regularView
#endif
            }
            .tabItem {
                Label("Chat", systemImage: "message.fill")
            }

            DownloadView()
                .tabItem {
                    Label("Hub", systemImage: "arrow.down.circle.fill")
                }
        }
        .onAppear {
            if let savedAgents = Store.shared.load() {
                agents = savedAgents

                // Resolve bookmarks to URLs for persistent access
                for i in 0..<agents.count {
                    if let data = agents[i].modelBookmarkData {
                        var isStale = false
                        if let resolvedURL = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale) {
                            agents[i].modelURL = resolvedURL
                            if isStale {
                                // Refresh bookmark if stale
                                let secure = resolvedURL.startAccessingSecurityScopedResource()
                                agents[i].modelBookmarkData = try? resolvedURL.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                                if secure { resolvedURL.stopAccessingSecurityScopedResource() }
                            }
                        }
                    }
                }
            }
            if let savedMessages = Store.shared.loadMessages() {
                messages = savedMessages
            }
        }
        .onChange(of: agents) { newAgents in
            Store.shared.save(agents: newAgents)
        }
        .onChange(of: messages) { newMessages in
            Store.shared.saveMessages(messages: newMessages)
        }
        .preferredColorScheme(.dark)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(clearTriggered: .constant(false))
    }
}

extension String {
    func deletingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }
}
