//
//  FileManager.swift
//  ExternalCamera
//
//  Created by 93bpm on 1/30/26.
//

import UIKit

extension FileManager {
    
    private var path: String { "ExternalCamera" }
    
    private var documentDirectory: URL { urls(for: .documentDirectory, in: .userDomainMask)[0] }
    
    private func path(at fileName: String) -> URL {
        documentDirectory.appending(path: "\(path)/\(fileName)")
    }
    
    func createDirectory() {
        let path = documentDirectory.appending(path: path)
        
        var isDirectory: ObjCBool = true
        
        let exists = fileExists(atPath: path.path(), isDirectory: &isDirectory)
        
        guard !(exists && isDirectory.boolValue) else { return }
        do {
            try createDirectory(
                at: path,
                withIntermediateDirectories: true
            )
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func saveImage(_ image: UIImage, name fileName: String) {
        guard let data = image.jpegData(compressionQuality: 1.0) else { return }
        do {
            try data.write(to: path(at: fileName), options: .completeFileProtection)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func fetchImage(for fileName: String) -> UIImage? {
        do {
            let data = try Data(contentsOf: path(at: fileName))
            return UIImage(data: data)
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    func removeImage(for fileName: String) {
        do {
            try removeItem(at: path(at: fileName))
        } catch {
            print(error.localizedDescription)
        }
    }
}
