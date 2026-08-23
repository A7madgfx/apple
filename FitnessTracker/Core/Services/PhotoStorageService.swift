//
//  PhotoStorageService.swift
//  Stores progress photos in the app's private Documents directory —
//  never in the system Photo Library — with a manual export option.
//

import Foundation
import UIKit
import Photos

final class PhotoStorageService {
    static let shared = PhotoStorageService()

    private let rootURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root = docs.appendingPathComponent("ProgressPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }()

    /// Saves a JPEG to private storage and returns the relative file name
    /// to be stored on a `ProgressPhoto` model.
    @discardableResult
    func save(_ image: UIImage, albumKey: String) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw StorageError.encodingFailed
        }
        let fileName = "\(albumKey)_\(UUID().uuidString).jpg"
        let url = rootURL.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return fileName
    }

    func loadImage(fileName: String) -> UIImage? {
        UIImage(contentsOfFile: rootURL.appendingPathComponent(fileName).path)
    }

    func url(for fileName: String) -> URL {
        rootURL.appendingPathComponent(fileName)
    }

    func delete(fileName: String) {
        try? FileManager.default.removeItem(at: rootURL.appendingPathComponent(fileName))
    }

    /// Manual "Export to Photos" — the only path that writes into the
    /// system Photo Library, and only when the user explicitly taps it.
    func exportToSystemPhotoLibrary(fileName: String) async throws {
        guard let image = loadImage(fileName: fileName) else { throw StorageError.notFound }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw StorageError.notAuthorized }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    enum StorageError: Error {
        case encodingFailed, notFound, notAuthorized
    }
}
