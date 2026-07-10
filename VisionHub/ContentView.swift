//
//  ContentView.swift
//  VisionHub
//
//  Created by wangjianhua on 7/10/26.
//

import SwiftUI
import SwiftData
import VisionHubCore

struct ContentView: View {
    var body: some View {
        VisionHubRootView()
    }
}

#Preview {
    ContentView()
        .modelContainer(
            try! VisionHubPersistence.makeModelContainer(
                cloudKitContainerIdentifier: nil,
                isStoredInMemoryOnly: true
            )
        )
}
