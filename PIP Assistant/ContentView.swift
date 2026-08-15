import SwiftUI

struct ContentView: View {
    @State var packages:[Package] = []
    @State private var visiblePackages:[Package] = []
    @State private var filteredPackages:[Package] = []
    @State private var currentPage = 0
    let pageSize = 100   // adjust for performance
    let loadNextPageThreshold = 20
    @State private var isShowingConfirmation = false
    @State private var isUpdating = false
    @StateObject private var retriever = Retriever()
    @State private var searchText = ""
    private var busy : Bool {
        !currentBlockingAction.isEmpty
    }
    @State private var currentBlockingAction=""
    @State private var busyMessage=""
    @State private var selectedPackage:Binding<Package>?=nil
    
    var body: some View {
        ZStack {
            VStack {
                ZStack {
                    Table($visiblePackages) {
                        TableColumn ("Name") { $pkg in
                            Text(pkg.name)
                                .onAppear {
                                    if(pkg.name==packages[currentPage*pageSize-loadNextPageThreshold].name){
                                        loadNextPage()
                                    }
                                }
                        }
                        .width(min:100)
                        TableColumn ("Version") { $pkg in
                            Text(pkg.version)
                        }
                        .width(min:50,max:130)
                        TableColumn("Status") { $pkg in
                            pkg.installedLabel()
                        }
                        .width(min:30,max:50)
                        TableColumn("Action") { $pkg in
                            HStack {
                                if(pkg.hasUpdates){
                                    Button(action: {
                                        selectedPackage=$pkg
                                        isUpdating=true
                                        isShowingConfirmation=true
                                    }) {
                                        Text("⬆️").help("Update")
                                    }
                                }
                                Button(action: {
                                    selectedPackage=$pkg
                                    isShowingConfirmation=true
                                    isUpdating=false
                                }) {
                                    pkg.installActionLabel()
                                }
                                .disabled(pkg.installed && !pkg.hasUpdates && isLocked(name: pkg.name))
                                .buttonStyle(.plain)
                                .confirmationDialog("Confirm Action", isPresented: $isShowingConfirmation) {
                                    if selectedPackage?.installed.wrappedValue ?? false {
                                        if isUpdating {
                                            Button("Upgrade") {
                                                currentBlockingAction="install_uninstall"
                                                busyMessage="Upgrading \(selectedPackage?.wrappedValue.name ?? "")"
                                                if let name = selectedPackage?.wrappedValue.name {
                                                    installUninstall(command: "upgrade", package: name)
                                                } else {
                                                    currentBlockingAction=""
                                                }
                                            }
                                        } else {
                                            Button("Uninstall", role: .destructive) {
                                                currentBlockingAction="install_uninstall"
                                                busyMessage="Uninstalling \(selectedPackage?.wrappedValue.name ?? "")"
                                                if let name = selectedPackage?.wrappedValue.name {
                                                    installUninstall(command: "uninstall", package: name)
                                                } else {
                                                    currentBlockingAction=""
                                                }
                                            }
                                        }
                                    } else {
                                        Button("Install") {
                                            currentBlockingAction="install_uninstall"
                                            busyMessage="Installing \(selectedPackage?.wrappedValue.name ?? "")"
                                            if let name = selectedPackage?.wrappedValue.name {
                                                installUninstall(command: "install", package: name)
                                            } else {
                                                currentBlockingAction=""
                                            }
                                        }
                                    }
                                    Button("Cancel", role: .cancel) {}
                                } message: {
                                    Text("Are you sure you want to \((selectedPackage?.installed.wrappedValue ?? false) ? (isUpdating ? "upgrade" : "uninstall") : "install") '\(selectedPackage?.wrappedValue.name ?? "")'?")
                                }
                            }
                        }
                        .width(min:30,max:50)
                    }
                    Color.clear
                        .searchable(text: $searchText, prompt: "Search packages")
                        .disabled(busy && (currentBlockingAction != "searching"))
                }
                .onChange(of: searchText, initial: true) { _, newValue in
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                        if Task.isCancelled { return }
                        await applyFilter(newValue)
                    }
                }
                .onAppear {
                    updatePackages()
                    NotificationCenter.default.addObserver(
                        forName: .trigRefresh,
                        object: nil,
                        queue: .main
                    ) { _ in
                        updatePackages()
                    }
                    NotificationCenter.default.addObserver(
                        forName: .installUninstallComplete,
                        object: nil,
                        queue: .main
                    ) { _ in
                        if currentBlockingAction=="install_uninstall" {
                            currentBlockingAction=""
                            updatePackages()
                        }
                    }

                }
                
            }
            if(busy){
                Rectangle().opacity(0.5).onTapGesture {}
                VStack {
                    Spinner()
                    Text(busyMessage).foregroundStyle(Color.white)
                }
            }
        }
        .onChange(of: busy,initial:true){ _,newBusy in
            NotificationCenter.default.post(
                name: .updateBusy,
                object: nil,
                userInfo: ["busy":newBusy]
            )
        }
    }
    
    private func updatePackages(){
        currentBlockingAction="refresh"
        busyMessage="Loading..."
        Task {
            packages = await retriever.fetchPyPiPackages()
            await applyFilter(searchText) // initial load
            let start = currentPage * pageSize
            let end = min(start + pageSize, filteredPackages.count)
            await updateVersions(start: start,end: end)
            print("update versions done")
            currentBlockingAction=""
        }
    }

    private func applyFilter(_ text: String) async {
        if(!text.isEmpty){
            currentBlockingAction="searching"
            busyMessage="Searching..."
        }
        let matches: [Package]
        if text.isEmpty {
            matches = packages
        } else {
            matches = packages.filter { pkg in
                pkg.name.localizedCaseInsensitiveContains(text)
            }
        }
        await MainActor.run {
            filteredPackages = matches
            currentPage = 0
            visiblePackages = []
            loadNextPage()
            currentBlockingAction=""
        }
    }

    private func updateVersions(start: Int, end: Int) async {
        let sliceIndices = filteredPackages.index(filteredPackages.startIndex, offsetBy: start)..<filteredPackages.index(filteredPackages.startIndex, offsetBy: min(end, filteredPackages.count))

        // 1. Fetch all versions concurrently via a TaskGroup
        let fetchedResults = await withTaskGroup(of: (Int, String).self) { group in
            for index in sliceIndices {
                let packageName = filteredPackages[index].name
                
                group.addTask {
                    // Fires all network requests at the exact same time
                    let version = await self.retriever.getVersionNumber(packageName: packageName)
                    return (index, version)
                }
            }
            
            // Collect results into a temporary dictionary
            var results: [Int: String] = [:]
            for await (index, version) in group {
                results[index] = version
            }
            return results
        }

        // 2. Safely update your array sequentially on a single thread
        for (index, version) in fetchedResults {
            filteredPackages[index].version = version
        }
    }

    
    private func loadNextPage() {
        currentBlockingAction="Loading more entries..."
        let start = currentPage * pageSize
        let end = min(start + pageSize, filteredPackages.count)
        if start < end {
            Task {
                await updateVersions(start: start,end: end)
                visiblePackages.append(contentsOf: filteredPackages[start..<end])
                currentPage += 1
                currentBlockingAction=""
            }
        }
    }

    private var endOfData: Bool {
        currentPage * pageSize >= filteredPackages.count
    }
}
