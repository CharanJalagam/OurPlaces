//
//  ImageCache.swift
//  OurPlaces
//
//  Created by apple on 07/03/26.
//


import SwiftUI
import CryptoKit

// MARK: - Image Cache
final class ImageCache {
    static let shared = ImageCache()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let diskCacheURL: URL
    
    private init() {
        // Memory cache limits
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 1024 * 1024 * 150  // 150 MB
        
        // Create disk cache folder in Caches directory
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = caches.appendingPathComponent("ImageCache", isDirectory: true)
        
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
    
    // MARK: - Get
    func get(_ url: String) -> UIImage? {
        // 1. Check memory first (fastest)
        if let cached = memoryCache.object(forKey: url as NSString) {
            return cached
        }
        
        // 2. Check disk
        let filePath = diskFilePath(for: url)
        guard fileManager.fileExists(atPath: filePath.path),
              let data = try? Data(contentsOf: filePath),
              let image = UIImage(data: data) else {
            return nil
        }
        
        // Promote back to memory cache
        memoryCache.setObject(image, forKey: url as NSString)
        return image
    }
    
    // MARK: - Set
    func set(_ image: UIImage, for url: String) {
        // Save to memory
        memoryCache.setObject(image, forKey: url as NSString)
        
        // Save to disk
        let filePath = diskFilePath(for: url)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: filePath)
        }
    }
    
    // MARK: - Clear (optional utility)
    func clearAll() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
    
    // Clears images older than given days (call on app launch to avoid unbounded growth)
    func clearExpired(olderThan days: Int = 30) {
        guard let files = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }
        
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        for file in files {
            let created = (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()
            if created < cutoff {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    // MARK: - Private
    private func diskFilePath(for url: String) -> URL {
        // Hash the URL to use as filename
        let fileName = url
            .data(using: .utf8)
            .map { SHA256.hash(data: $0) }
            .map { $0.compactMap { String(format: "%02x", $0) }.joined() }
        ?? url.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        
        return diskCacheURL.appendingPathComponent(fileName)
    }
}

// MARK: - Cache Phase (mirrors AsyncImagePhase)
enum CachedImagePhase {
    case empty
    case success(Image)
    case failure
}

// MARK: - CachedAsyncImage
struct CachedAsyncImage<Content: View>: View {
    private let url: URL?
    private let content: (CachedImagePhase) -> Content
    
    @State private var phase: CachedImagePhase = .empty

    init(
        url: URL?,
        @ViewBuilder content: @escaping (CachedImagePhase) -> Content
    ) {
        self.url = url
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                await loadImage()
            }
    }

    private func loadImage() async {
        guard let url else {
            phase = .failure
            return
        }

        // Return cached image instantly
        if let cached = ImageCache.shared.get(url.absoluteString) {
            phase = .success(Image(uiImage: cached))
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                ImageCache.shared.set(uiImage, for: url.absoluteString)
                phase = .success(Image(uiImage: uiImage))
            } else {
                phase = .failure
            }
        } catch {
            phase = .failure
        }
    }
}
