//
//  VisionHubApp.swift
//  VisionHub
//
//  Created by wangjianhua on 7/10/26.
//

import SwiftUI
import SwiftData
import VisionHubCore

@main
struct VisionHubApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try VisionHubPersistence.makeModelContainer()
        } catch {
            fatalError("Unable to create VisionHub data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            VisionHubRootView()
        }
        .modelContainer(modelContainer)
    }
}
