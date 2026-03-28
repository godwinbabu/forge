import SwiftUI

@Observable
final class AppState {
    var isBlockActive = false
    var blockEndDate: Date?
    var activeProfileName: String?
}
