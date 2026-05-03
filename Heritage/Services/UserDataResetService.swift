import Foundation

enum UserDataResetService {
    static func deleteAllUserData() throws {
        clearUserDefaults()

        let fileManager = FileManager.default
        try clearDirectory(.documentDirectory, fileManager: fileManager)
        try clearDirectory(.cachesDirectory, fileManager: fileManager)
        try clearTemporaryDirectory(fileManager: fileManager)
    }

    private static func clearUserDefaults() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        UserDefaults.standard.synchronize()
    }

    private static func clearDirectory(
        _ directory: FileManager.SearchPathDirectory,
        fileManager: FileManager
    ) throws {
        guard let url = fileManager.urls(for: directory, in: .userDomainMask).first else {
            return
        }

        try removeContents(of: url, fileManager: fileManager)
    }

    private static func clearTemporaryDirectory(fileManager: FileManager) throws {
        try removeContents(
            of: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
            fileManager: fileManager
        )
    }

    private static func removeContents(of directoryURL: URL, fileManager: FileManager) throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return
        }

        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for url in contents {
            try fileManager.removeItem(at: url)
        }
    }
}
