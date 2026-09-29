//
//  ControlView.swift
//  xac
//
//  Created by Cyril Zakka on 4/3/23.
//

import SwiftUI
import CompactSlider
import Models
import Generation
import UniformTypeIdentifiers

struct ControlView: View {
    var prompt: String = ""
    @Binding var config: GenerationConfig
    @Binding var model: LanguageModel? // Keeps active model loaded in UI memory
    @Binding var agents: [AgentRole] // New workflow state

    @State var discloseParams = true

    @State var discloseAdvanced = true
    @State private var topK = 40.0
    @State private var freqPenalty = 2.0
    @State private var presPenalty = 0.9

    @State var disclosedModel = true
    @State private var showFilePicker = false
    @State private var activeAgentIndexForPicker: Int? = nil


    var body: some View {
        VStack(alignment: .leading) {
            ScrollView {
                Group {
                    DisclosureGroup(isExpanded: $discloseParams) {
                        Spacer()
                        CompactSlider(value: $config.temperature, in: 0...2, direction: .center) {
                            Text("Temperature")
                            Spacer()
                            Text("\(config.temperature, specifier: "%.2f")")
                        }.compactSliderStyle(
                            .prominent(
                                lowerColor: .blue,
                                upperColor: .red,
                                useGradientBackground: true
                            )
                        )
                        .compactSliderSecondaryColor(config.temperature <= 0.5 ? .blue : .red)
                        .disabled(!config.doSample)
                        .help("Controls randomness: Lowering results in less random completions. As the temperature approaches zero, the model will become deterministic and repetitive.")

                        CompactSlider(value: Binding {
                            CFloat(config.topK)
                        } set: {
                            config.topK = Int($0)
                        }, in: 1...50, step: 1) {
                            Text("Top K")
                            Spacer()
                            Text("\(config.topK)")
                        }
                        .compactSliderSecondaryColor(.blue)
                        .disabled(!config.doSample)
                        .help("Sort predicted tokens by probability and discards those below the k-th one. A top-k value of 1 is equivalent to greedy search (select the most probable token)")

                        CompactSlider(value: Binding {
                            CFloat(config.maxNewTokens)
                        } set: {
                            config.maxNewTokens = Int($0)
                        }, in: CFloat(1)...CFloat(2048), step: 1) {
                            Text("Maximum Length")
                            Spacer()
                            Text("\(Int(config.maxNewTokens))")
                        }
                        .compactSliderSecondaryColor(.blue)
                        .help("The maximum number of tokens to generate. Requests can use up to 2,048 tokens shared between prompt and completion. The exact limit varies by model. (One token is roughly 4 characters for normal English text)")
                    } label: {
                       HStack {
                           Label("Parameters", systemImage: "slider.horizontal.3").foregroundColor(.secondary)
                           Spacer()
                       }
                   }
                }

                HStack {
                    Toggle(isOn: $config.doSample) { Text("Sample") }
                    Spacer()
                }

                Divider()

                Group {
                    DisclosureGroup(isExpanded: $discloseAdvanced) {
                        Spacer()
                        CompactSlider(value: $config.topP) {
                            Text("Top P")
                            Spacer()
                            Text("\(config.topP, specifier: "%.2f")")
                        }
                        .help("Controls diversity via nucleus sampling: 0.5 means half of all likelihood-weighted options are considered.")
                        CompactSlider(value: Binding {
                            Darwin.sqrt(CGFloat(config.repetitionPenalty))
                        } set: {
                            config.repetitionPenalty = Float(Darwin.pow($0, 2))
                        }, in: 1...sqrt(CGFloat(10))) {
                            Text("Frequency Penalty")
                            Spacer()
                            Text("\(config.repetitionPenalty, specifier: "%.1f")")
                        }.help("How much to penalize new tokens based on their existing frequency in the text so far. Decreases the model's likelihood to repeat the same line verbatim.")
                     } label: {
                        HStack {
                            Label("Advanced", systemImage: "wrench.adjustable").foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                     .compactSliderSecondaryColor(.blue)
                }

                Divider()

                Group {
                    DisclosureGroup(isExpanded: $disclosedModel) {
                        VStack(alignment: .leading, spacing: 12) {
                            Menu {
                                Button("Ultra Pipeline (10 Agents)") {
                                    let firstURL = agents.first?.modelURL
                                    let firstBookmark = agents.first?.modelBookmarkData

                                    let ultraRoles = [
                                        ("Analyst", "You are an expert analyst. Understand the user's problem deeply, clarify the requirements, and propose a high-level solution architecture."),
                                        ("Architect", "You are a software architect. Take the Analyst's solution and design the concrete class structures, design patterns, and module boundaries."),
                                        ("Lead Developer", "You are the Lead Developer. Take the Architect's design and write the initial implementation of the code."),
                                        ("Syntax Auditor", "You are a compiler expert. Review the Lead Developer's code for any syntax errors, deprecations, or compilation issues and fix them."),
                                        ("Security Expert", "You are a cybersecurity expert. Review the code for vulnerabilities, injection flaws, or unsafe data handling. Rewrite it securely."),
                                        ("Performance Optimizer", "You are an optimization expert. Analyze the code's time and space complexity. Rewrite it to be as fast and efficient as possible."),
                                        ("QA Tester", "You are a QA engineer. Think of edge cases and write unit tests for the current code implementation."),
                                        ("Refactor Specialist", "You are a clean code advocate. Refactor the code to improve readability, variable naming, and DRY principles without changing functionality."),
                                        ("Technical Writer", "You are a documentation expert. Add comprehensive comments and docstrings to the code explaining how it works."),
                                        ("Final Reviewer", "You are the project manager. Review all previous steps. Provide the final, polished code block and a brief summary of the changes made.")
                                    ]

                                    agents = ultraRoles.map {
                                        AgentRole(name: $0.0, systemPrompt: $0.1, modelURL: firstURL, modelBookmarkData: firstBookmark)
                                    }
                                }

                                Button("Clear All") {
                                    agents = []
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "wand.and.stars")
                                    Text("Load Template")
                                }
                                .padding(.vertical, 4)
                            }

                            ForEach($agents) { $agent in
                                VStack(alignment: .leading) {
                                    HStack {
                                        TextField("Agent Role", text: $agent.name)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                        Button(action: {
                                            if let index = agents.firstIndex(where: { $0.id == agent.id }) {
                                                agents.remove(at: index)
                                            }
                                        }) {
                                            Image(systemName: "minus.circle.fill").foregroundColor(.red)
                                        }
                                    }

                                    TextField("System Prompt...", text: $agent.systemPrompt)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.caption)

                                    Button(action: {
                                        if let index = agents.firstIndex(where: { $0.id == agent.id }) {
                                            activeAgentIndexForPicker = index
                                            showFilePicker.toggle()
                                        }
                                    }, label: {
                                        Text(agent.modelURL?.lastPathComponent ?? "Select Model for \(agent.name)...")
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 7)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 5)
                                                    .stroke(Color.secondary, lineWidth: 1)
                                            )
                                    })
                                    .buttonStyle(.borderless)
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }

                            Button(action: {
                                agents.append(AgentRole(name: "New Agent", systemPrompt: "You are an assistant.", modelURL: nil))
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Agent to Chain")
                                }
                            }
                            .padding(.top, 4)
                        }
                        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.mlpackage, .mlmodelc], allowsMultipleSelection: false) { result in
                            switch result {
                            case .success(let urls):
                                if let index = activeAgentIndexForPicker, let url = urls.first {
                                    let secure = url.startAccessingSecurityScopedResource()
                                    do {
                                        let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                                        agents[index].modelURL = url
                                        agents[index].modelBookmarkData = bookmarkData
                                    } catch {
                                        print("Failed to create bookmark: \(error)")
                                    }
                                    if secure { url.stopAccessingSecurityScopedResource() }
                                }
                            case .failure(let error):
                                print("Import failed: \(error.localizedDescription)")
                            }
                            activeAgentIndexForPicker = nil
                        }
                    } label: {
                        HStack {
                            Label("Agent Workflow", systemImage: "person.3.sequence").foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }

            }
        }
        .padding()
    }
}

private extension UTType {
    static let mlpackage = UTType(filenameExtension: "mlpackage", conformingTo: .item)!
    static let mlmodelc = UTType(filenameExtension: "mlmodelc", conformingTo: .item)!
}
