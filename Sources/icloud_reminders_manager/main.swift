import Foundation

let app = App()
Task {
    do {
        try await app.run()
    } catch {
        print("Error: \(error)")
    }
} 