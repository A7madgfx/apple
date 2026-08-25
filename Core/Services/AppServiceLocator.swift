import Foundation

/// Lightweight locator so screens instantiated by NavigationStack destinations (which
/// don't get initializer-injected services) can reach shared services.
/// Configured once from AppState at launch.
enum AppServiceLocator {
    static var azkarService: AzkarService!
}
