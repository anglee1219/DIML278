import SwiftUI

struct CreateGroupView: View {
    @State private var numberOfPages = 5
    @State private var gridSpacing = 20.0

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(0..<numberOfPages, id: \.self) { page in
                        VStack {
                            LazyHGrid(
                                rows: [
                                    GridItem(.fixed(120), spacing: gridSpacing),
                                    GridItem(.fixed(120), spacing: gridSpacing)
                                ],
                                spacing: gridSpacing
                            ) {
                                // ... existing code ...
                            }
                        }
                    }
                }
            }
        }
    }
}

struct CreateGroupView_Previews: PreviewProvider {
    static var previews: some View {
        CreateGroupView()
    }
} 