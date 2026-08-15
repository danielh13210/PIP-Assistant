import Foundation
import SwiftUI

struct Package : Identifiable, Equatable{
    
    var id: String { name }
    let name: String
    let version: String
    var installed: Bool
    var hasUpdates: Bool
    var installedMsg :String {
        (installed ? "✔️" : "")+(hasUpdates ? "⬆️" : "")+(installed && isLocked(name: name) ? "🔒" : "")
    }
    @ViewBuilder func installedLabel() -> some View {
        HStack{
            if(installed){
                Text("✔️").help("Installed")
            }
            if(hasUpdates) {
                Text("⬆️").help("Has updates")
            }
            if(installed && isLocked(name: name)){
                Text("🔒").help("Critical package, cannot be uninstalled")
            }
        }
    }
    var installAction: String {
        installed ? "🗑️" : "⬇️"
    }
    @ViewBuilder func installActionLabel() -> some View {
        HStack{
            if(installed){
                Text("🗑️").help("Uninstall")
            } else {
                Text("⬇️").help("Install")
            }
        }
    }
    static func == (lhs: Package, rhs: Package) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.version == rhs.version &&
        lhs.installed == rhs.installed
    }
}

struct PackageInfo: Codable {
    let info: PackageInfoMain?;
}

struct PackageInfoMain : Codable{
    let version:String
}
