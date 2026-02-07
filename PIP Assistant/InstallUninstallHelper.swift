//
//  InstallUninstallHelper.swift
//  PIP Assistant
//
//  Created by Tinkertanker on 31/1/26.
//

import Foundation

import SwiftUI

enum FileError: Error {
    case noSuchFile(path: String)
}

// prevent these from being uninstalled
let locked_packages = ["pip"]

func installUninstall(command: String, package: String) {
    let fileManager = FileManager.default
    
    // 1. Create a temporary destination
    let tempDir = fileManager.temporaryDirectory
    let tempFileURL = tempDir.appendingPathComponent("\(command)_\(package).command")
    
    do {
        // 2. Copy file into temp directory
        if fileManager.fileExists(atPath: tempFileURL.path) {
            try fileManager.removeItem(at: tempFileURL)
        }
        guard let templateCmdFile=Bundle.main.url(forResource: "install_uninstall", withExtension: "sh")
        else {throw FileError.noSuchFile(path: "install_uninstall.sh")}
        try fileManager.copyItem(at: templateCmdFile, to: tempFileURL)
        
        // 3. Load file contents
        var contents = try String(contentsOf: tempFileURL, encoding: .utf8)
        
        // fill in the template
        contents = contents.replacingOccurrences(of: "{{CMD}}", with: command).replacingOccurrences(of: "{{PACKAGE_NAME}}", with: package)
        
        // 5. Write back modified contents
        try contents.write(to: tempFileURL, atomically: true, encoding: .utf8)
        print(tempFileURL.absoluteString.replacingOccurrences(of: "file://", with: ""))
        
        // 6. Open with default app
        NSWorkspace.shared.open(tempFileURL)
        
    } catch {
        print("Error processing file: \(error)")
    }
}

func runShellScriptAndCaptureOutput(at scriptURL: URL) -> String {
    let process = Process()
    process.executableURL = scriptURL   // your script must be executable (chmod +x)
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            return output
        }
    } catch {
        print("Error running script: \(error)")
    }
    return ""
}

// List locally installed packages
func listPackages() -> [String] {
    if let scriptURL = Bundle.main.url(forResource: "pkglist", withExtension: "sh") {
        let data=runShellScriptAndCaptureOutput(at: scriptURL)
        do {
            let json=try JSONDecoder().decode([String].self, from: data.data(using: .utf8)!)
            return json
        } catch {
            print("Error decoding: \(error)")
        }
    }
    return []
}

func isLocked(name: String) -> Bool {
    return locked_packages.contains(name)
}
