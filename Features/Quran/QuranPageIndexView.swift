import SwiftUI

/// Every one of the Mushaf's 604 standard pages, individually accessible.
struct QuranPageIndexView: View {
    private let totalPages = 604
    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(1...totalPages, id: \.self) { page in
                    NavigationLink(value: PageRoute(page: page)) {
                        Text("\(page)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 44)
                            .background(AppTheme.secondaryBlack, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding()
        }
        .navigationDestination(for: PageRoute.self) { route in
            QuranReaderView(mode: .page(route.page))
        }
    }
}

struct PageRoute: Hashable { let page: Int }
