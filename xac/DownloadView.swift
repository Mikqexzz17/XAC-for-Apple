import SwiftUI

struct DownloadView: View {
    @StateObject private var downloader = Downloader()

    // Example CoreML models for iOS (Note: these URLs are placeholders for actual model zips)
    let models = [
        ("Llama 3 8B (4-bit)", "https://huggingface.co/coreml-projects/Llama-3-8B-Instruct-coreml/resolve/main/Llama-3-8B.mlpackage.zip"),
        ("CodeLlama 7B (4-bit)", "https://huggingface.co/coreml-projects/CodeLlama-7b-Instruct-hf-coreml/resolve/main/CodeLlama-7b.mlpackage.zip"),
        ("Mistral 7B (4-bit)", "https://huggingface.co/coreml-projects/Mistral-7B-Instruct-v0.2-coreml/resolve/main/Mistral-7B.mlpackage.zip")
    ]

    var body: some View {
        NavigationView {
            VStack {
                Text("Models are downloaded as .zip to your Files app. Please unzip them via the Files app before selecting them in the Chat view.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding()
                    .multilineTextAlignment(.center)

                List(models, id: \.0) { model in
                    VStack(alignment: .leading, spacing: 8) {
                    Text(model.0)
                        .font(.headline)

                    if downloader.isDownloading {
                        ProgressView(value: downloader.progress)
                            .progressViewStyle(.linear)
                        Text("\(Int(downloader.progress * 100))%")
                            .font(.caption)
                    } else {
                        Button(action: {
                            if let url = URL(string: model.1) {
                                downloader.download(url: url, filename: model.1.components(separatedBy: "/").last ?? "model.zip")
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Download")
                            }
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 4)
                }
            }
            .navigationTitle("Model Hub")
        }
    }
}
