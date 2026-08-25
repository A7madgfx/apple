//
//  RootTabView.swift
//  The 4-tab main navigation shell.
//

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var router: DeepLinkRouter
    @State private var selection: Tab = .today
    @State private var showMorningCamera = false

    enum Tab: Hashable { case today, stats, gallery, settings }

    var body: some View {
        TabView(selection: $selection) {
            TodayView()
                .tabItem { Label("اليوم", systemImage: "sun.max.fill") }
                .tag(Tab.today)

            StatsView()
                .tabItem { Label("الإحصائيات", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(Tab.stats)

            GalleryView()
                .tabItem { Label("المعرض", systemImage: "photo.stack.fill") }
                .tag(Tab.gallery)

            SettingsRoutineView()
                .tabItem { Label("الإعدادات", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .background(AppTheme.background)
        .onReceive(NotificationCenter.default.publisher(for: .openMorningCamera)) { _ in
            showMorningCamera = true
        }
        .fullScreenCover(isPresented: $showMorningCamera) {
            MorningReviewCameraView()
        }
    }
}
