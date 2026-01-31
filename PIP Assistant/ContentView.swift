import SwiftUI

extension View {
    // Observes the width of a view and writes it back into a binding.
    func persistWidth(to binding: Binding<Double>) -> some View {
        self.background(
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.size.width,initial: false) { _,newWidth in
                        print(newWidth)
                        binding.wrappedValue = newWidth
                    }
            }
        )
    }
}

struct ContentView: View {
    @State var packages:[Package] = []
    @State private var visiblePackages:[Package] = []
    @State private var filteredPackages:[Package] = []
    @State private var currentPage = 0
    let pageSize = 500   // adjust for performance
    @State private var isShowingConfirmation = false
    @StateObject private var retriever = Retriever()
    @State private var searchText = ""
    private var busy : Bool {
        !currentBlockingAction.isEmpty
    }
    @State private var currentBlockingAction=""
    @State private var busyMessage=""
    @State private var selectedPackage:Binding<Package>?=nil
    
    @AppStorage("nameColumnWidth") private var nameColumnWidth: Double = 200
    @AppStorage("versionColumnWidth") private var versionColumnWidth: Double = 80
    @AppStorage("installedColumnWidth") private var installedColumnWidth: Double = 50
    @AppStorage("actionColumnWidth") private var actionColumnWidth: Double = 50
    
    var body: some View {
        ZStack {
            VStack {
                ZStack {
                    Table($visiblePackages) {
                        TableColumn ("Name") { $pkg in
                            Text(pkg.name)
                                .persistWidth(to: $nameColumnWidth)
                        }
                        .width(min:100,ideal:nameColumnWidth)
                        TableColumn ("Version") { $pkg in
                            Text(pkg.version)
                                .persistWidth(to: $versionColumnWidth)
                        }
                        .width(min:50,ideal:versionColumnWidth,max:130)
                        TableColumn("Installed") { $pkg in
                            Text(pkg.installedMsg)
                                .persistWidth(to: $installedColumnWidth)
                        }
                        .width(min:30,ideal:installedColumnWidth,max:50)
                        TableColumn("Action") { $pkg in
                            Button(action: {
                                selectedPackage=$pkg
                                isShowingConfirmation=true
                            }) {
                                Text(pkg.installAction)
                            }
                            .persistWidth(to: $actionColumnWidth)
                            .buttonStyle(.plain)
                            .confirmationDialog("Confirm Action", isPresented: $isShowingConfirmation) {
                                if selectedPackage?.installed.wrappedValue ?? false {
                                    Button("Uninstall", role: .destructive) {
                                        currentBlockingAction="install_uninstall"
                                        busyMessage="Uninstalling \(selectedPackage?.wrappedValue.name ?? "")"
                                    }
                                } else {
                                    Button("Install") {
                                        currentBlockingAction="install_uninstall"
                                        busyMessage="Installing \(selectedPackage?.wrappedValue.name ?? "")"
                                    }
                                }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text("Are you sure you want to \((selectedPackage?.installed.wrappedValue ?? false) ? "uninstall" : "install") '\(selectedPackage?.wrappedValue.name ?? "")'?")
                            }
                        }
                        .width(min:30,ideal:actionColumnWidth,max:50)
                    }
                    Color.clear
                        .searchable(text: $searchText, prompt: "Search packages")
                        .disabled(busy && (currentBlockingAction != "searching"))
                }
                .onChange(of: searchText, initial: true) { _, newValue in
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                        if Task.isCancelled { return }
                        applyFilter(newValue)
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

                }
                
                HStack {
                    Button("Load More") {
                        loadNextPage()
                    }
                    .disabled(endOfData)
                }
                .padding()
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
            applyFilter(searchText) // initial load
            currentBlockingAction=""
        }
    }

    private func applyFilter(_ text: String) {
        if(!text.isEmpty){
            currentBlockingAction="searching"
            busyMessage="Searching..."
        }
        Task.detached {
            let matches: [Package]
            if text.isEmpty {
                matches = await packages
            } else {
                matches = await packages.filter { pkg in
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
    }

    private func loadNextPage() {
        let start = currentPage * pageSize
        let end = min(start + pageSize, filteredPackages.count)
        if start < end {
            visiblePackages.append(contentsOf: filteredPackages[start..<end])
            currentPage += 1
        }
    }

    private var endOfData: Bool {
        currentPage * pageSize >= filteredPackages.count
    }
}
