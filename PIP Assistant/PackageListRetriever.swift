import Foundation
import SwiftUI
internal import Combine

class Retriever : ObservableObject{
    @Published var ready = false;
    @Published var failed = false;
    var block=0;
    func fetchPyPiPackages() async -> [Package]{
        ready=false
        failed=false
        guard let url = URL(string: "http://pypi.org/simple") else { 
            failed=true
            ready=true
            return []
        }
        
        let packages_installed=listPackages()
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            print("Data fetched")
            let responseText = String(data: data, encoding: .utf8)
            let names=reapPackageNames(html: responseText ?? "")
            print("Names reaped")
            if names.isEmpty {
                print("Error fetching data: response empty or corrupted")
                failed=true
                ready=true
                return []
            }
            else {
                var packages: [Package] = []
                for i in 0..<names.count {
                    let name=names[i]
                    packages.append(Package(name: name, version: "",installed: packages_installed.contains(name)))
                }
                if(!failed) {
                    ready=true
                    return packages
                }
            }
        } catch {
            print("Error fetching data: \(error)")
            failed=true
            ready=true
            return []
        }
        failed=true
        ready=true
        return []
    }
    
    func reapPackageNames(html: String) -> [String]{
        let pattern = "<a[^>]*>(.*?)</a>"
        var packageNames : [String] = []
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsString = html as NSString
            let results = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in results {
                let linkText = nsString.substring(with: match.range(at: 1))
                packageNames.append(linkText)
            }
            return packageNames
        } catch {
            print("Regex error: \(error)")
        }
        failed=true
        return []
    }
 
    func getVersionNumber(packageName: String) async -> String {
        //print("Getting version for package \(packageName)")
        guard let url = URL(string: "https://pypi.org/pypi/\(packageName)/json") else
        {
            failed=true
            return "" 
        }
            
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let package = try JSONDecoder().decode(PackageInfo.self, from: data)
            return (package.info ?? PackageInfoMain(version: "")).version
            //return ""
        } catch let DecodingError.keyNotFound(key, context) {
            print("Missing key:", key.stringValue)
            print("Debug Description:", context.debugDescription)
            failed=true
            return ""
        } catch {
            print("Error decoding: \(error)")
            failed=true
            return ""
        }
    }
}
