import Foundation

class Downloader: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var isDownloading = false
    @Published var progress: Double = 0.0

    private var downloadTask: URLSessionDownloadTask?
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    func download(url: URL, filename: String) {
        guard !isDownloading else { return }

        DispatchQueue.main.async {
            self.isDownloading = true
            self.progress = 0.0
        }

        // Use a simple temporary download for .mlpackage zips or .mlmodelc folders
        // Real Hugging Face Hub downloads require dealing with LFS and multiple files,
        // but for iOS CoreML models they are often distributed as a single zipped archive.
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Move downloaded file to documents directory
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
              let originalURL = downloadTask.originalRequest?.url else { return }

        let destinationURL = documentsURL.appendingPathComponent(originalURL.lastPathComponent)

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)
            DispatchQueue.main.async {
                self.isDownloading = false
                self.progress = 1.0
            }
            print("Successfully downloaded to \(destinationURL)")
        } catch {
            print("Error moving downloaded file: \(error)")
            DispatchQueue.main.async {
                self.isDownloading = false
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let calculatedProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.progress = calculatedProgress
        }
    }
}
