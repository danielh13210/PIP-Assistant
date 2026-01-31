//
//  lazyvlistApp.swift
//  lazyvlist
//
//  Created by Tinkertanker on 24/1/26.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

@main
struct PIPAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var busy = false
    var body: some Scene {
        WindowGroup {
            ContentView()
        }.commands {
            // Replaces the "New Window" (newItem) group with an empty view
            CommandGroup(replacing: .newItem) {
                Button("Refresh"){
                    NotificationCenter.default.post(
                        name: .trigRefresh,
                        object: nil,
                    )
                }
                .disabled(busy)
                .keyboardShortcut("r",modifiers: [.command])
                .onAppear{
                    NotificationCenter.default.addObserver(
                        forName: .updateBusy,
                        object: nil,
                        queue: .main
                    ) { notification in
                        if let newBusy = notification.userInfo?["busy"] as? Bool {
                            print("is busy: \(newBusy)")
                            busy=newBusy
                        }
                    }
                }
            }
        }
    }
}

extension Notification.Name {
    static let trigRefresh = Notification.Name("trigRefresh")
    static let updateBusy = Notification.Name("updateBusy")
}
