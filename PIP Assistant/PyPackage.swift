import Foundation

struct Package : Identifiable, Equatable{
    
    let id=UUID()
    let name: String
    let version: String
    var installed: Bool
    var hasUpdates: Bool
    var installedMsg :String {
        (installed ? "✔️" : "")+(hasUpdates ? "⬆️" : "")+(installed && isLocked(name: name) ? "🔒" : "")
    }
    var installAction: String {
        installed ? "🗑️" : "⬇️"
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
