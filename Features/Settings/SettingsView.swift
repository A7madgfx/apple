import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: SettingsStore
    @State private var showFilePicker = false
    @State private var pickerError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBlack.ignoresSafeArea()
                Form {
                    prayersSection
                    audioSection
                    calculationSection
                    verificationSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("الإعدادات")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.mp3, .mpeg4Audio, .wav, .audio], allowsMultipleSelection: false) { result in
            handlePicked(result)
        }
        .alert("خطأ", isPresented: .constant(pickerError != nil), actions: {
            Button("حسنًا") { pickerError = nil }
        }, message: { Text(pickerError ?? "") })
    }

    private var prayersSection: some View {
        Section("الصلاة") {
            ForEach(Prayer.allCases) { prayer in
                Toggle(isOn: Binding(
                    get: { settings.isPrayerEnabled(prayer) },
                    set: { settings.setPrayerEnabled(prayer, enabled: $0) }
                )) {
                    Text("تفعيل تنبيه \(prayer.arabicName)")
                }
                .tint(AppTheme.primaryYellow)
            }
        }
        .listRowBackground(AppTheme.secondaryBlack)
    }

    private var audioSection: some View {
        Section("الصوت") {
            Picker("صوت الأذان", selection: $settings.audioSourceKind) {
                Text("الأذان الافتراضي").tag(AudioSourceKind.defaultAdhan)
                Text("نغمة مخصصة").tag(AudioSourceKind.custom)
            }
            if settings.audioSourceKind == .custom {
                HStack {
                    Text(settings.customAudioDisplayName ?? "لم يتم اختيار ملف")
                        .foregroundStyle(AppTheme.secondaryText)
                    Spacer()
                    Button("اختيار ملف") { showFilePicker = true }
                        .foregroundStyle(AppTheme.primaryYellow)
                }
            }
            Button("معاينة الصوت") { previewAudio() }
                .foregroundStyle(AppTheme.primaryYellow)
            HStack {
                Text("مستوى الصوت")
                Slider(value: $settings.volume, in: 0...1)
                    .tint(AppTheme.primaryYellow)
            }
        }
        .listRowBackground(AppTheme.secondaryBlack)
    }

    private var calculationSection: some View {
        Section("مواقيت الصلاة") {
            Picker("طريقة الحساب", selection: $settings.calculationMethod) {
                ForEach(CalculationMethod.allCases) { method in
                    Text(method.arabicName).tag(method)
                }
            }
            Picker("طريقة العصر", selection: $settings.asrMethod) {
                ForEach(AsrJuristicMethod.allCases) { method in
                    Text(method.arabicName).tag(method)
                }
            }
            HStack {
                Text("الموقع الحالي")
                Spacer()
                Text(settings.placemarkName ?? "غير محدد").foregroundStyle(AppTheme.secondaryText)
            }
            Button("تحديث الموقع") {
                Task { await appState.scheduleService.refresh() }
            }
            .foregroundStyle(AppTheme.primaryYellow)
        }
        .listRowBackground(AppTheme.secondaryBlack)
        .onChange(of: settings.calculationMethod) { _, _ in Task { await appState.scheduleService.refresh() } }
        .onChange(of: settings.asrMethod) { _, _ in Task { await appState.scheduleService.refresh() } }
    }

    private var verificationSection: some View {
        Section("التحقق") {
            VStack(alignment: .trailing, spacing: 6) {
                Text("التحقق من سجادة الصلاة مفعّل دائمًا")
                    .foregroundStyle(.white)
                Text("عند تفعيل تنبيه صلاة، لا يمكن إيقاف الصوت إلا بتصوير سجادة الصلاة والتحقق منها على الجهاز.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.trailing)
            }
            Text("تعليمات التصوير: ضع السجادة ممددة بالكامل على الأرض في مكان مضاء جيدًا، والتقط الصورة من مسافة تُظهرها كاملة.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .listRowBackground(AppTheme.secondaryBlack)
    }

    private func previewAudio() {
        do {
            if settings.audioSourceKind == .defaultAdhan, let url = Bundle.main.url(forResource: "default_adhan", withExtension: "mp3") {
                try appState.audioManager.preview(url: url)
            } else if let bookmark = settings.customAudioBookmark {
                var stale = false
                if let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale), url.startAccessingSecurityScopedResource() {
                    try appState.audioManager.preview(url: url)
                    url.stopAccessingSecurityScopedResource()
                }
            }
        } catch {
            pickerError = "تعذر تشغيل الملف الصوتي."
        }
    }

    private func handlePicked(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                try appState.audioManager.storeCustomAudio(pickedURL: url, displayName: url.lastPathComponent)
            } catch {
                pickerError = "صيغة الملف الصوتي غير مدعومة."
            }
        case .failure:
            pickerError = "تعذر اختيار الملف."
        }
    }
}
