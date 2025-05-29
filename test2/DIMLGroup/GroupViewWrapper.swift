import SwiftUI

struct GroupViewWrapper: View {
    @StateObject var store = EntryStore()
    @State private var currentGroup: Group? = nil
    @State private var showFeed = false

    var body: some View {
        if showFeed, let group = currentGroup {
            DIMLView(store: store, group: group)
        } else {
            GroupViewWithCompletion { group in
                self.currentGroup = group
                self.showFeed = true
            }
        }
    }
}


