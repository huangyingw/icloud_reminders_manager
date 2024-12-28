// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import EventKit

Task {
    do {
        let app = App()
        try await app.run()
    } catch {
        print("Error: \(error)")
        exit(1)
    }
}
