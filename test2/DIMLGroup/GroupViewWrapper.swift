import SwiftUI

struct GroupViewWrapper: View {
    @State private var currentGroup: Group? = nil
    @State private var showFeed = false

    var body: some View {
        if showFeed, let group = currentGroup {
            DIMLView(group: group)
        } else {
            GroupViewWithCompletion { group in
                self.currentGroup = group
                self.showFeed = true
            }
        }
    }
}


