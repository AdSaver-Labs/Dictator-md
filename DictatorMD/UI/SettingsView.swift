import AppKit
import SwiftUI
import Carbon.HIToolbox

private enum AppTheme {
    static let logoYellow = Color(red: 0.973, green: 0.752, blue: 0.236)
    static let logoYellowSoft = Color(red: 1.0, green: 0.82, blue: 0.25)
    static let ink = Color(red: 0.09, green: 0.09, blue: 0.08)
    static let graphite = Color(red: 0.18, green: 0.18, blue: 0.17)
    static let readyGreen = logoYellow
    static let cyan = Color(red: 0.42, green: 0.78, blue: 1.0)

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [logoYellowSoft, logoYellow],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var selectedGradient: LinearGradient {
        LinearGradient(
            colors: [logoYellow, Color(red: 0.93, green: 0.66, blue: 0.13)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension AppSettings.AppearanceMode {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .auto: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

// MARK: - Settings Window

struct SettingsView: View {
    let engine: DictationEngine
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var modelManager = ModelManager.shared
    @ObservedObject private var permissions = PermissionManager.shared
    @ObservedObject private var memory = DictationMemory.shared
    @State private var selectedSection: SettingsSection = .dashboard
    @State private var showOnboarding = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.colorScheme) private var colorScheme

    enum SettingsSection: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case general = "Control"
        case model = "Engine"
        case history = "History"
        case vocabulary = "Vocabulary"
        case protocols = "Protocols"
        case permissions = "Access"

        var id: String { rawValue }

        static var allCases: [SettingsSection] {
            [.dashboard, .history, .vocabulary, .model, .general, .permissions]
        }

        var displayName: String {
            switch self {
            case .dashboard: "Dashboard"
            case .history: "History"
            case .vocabulary: "Vocabulary"
            case .model: "Models"
            case .general: "Control Center"
            case .permissions: "Settings"
            case .protocols: "Protocols"
            }
        }

        var icon: String {
            switch self {
            case .dashboard: "house"
            case .general: "shield"
            case .model: "brain"
            case .history: "clock.arrow.circlepath"
            case .vocabulary: "book"
            case .protocols: "list.bullet.clipboard.fill"
            case .permissions: "gearshape"
            }
        }
    }

    var body: some View {
        ZStack {
            premiumBackground

            HStack(spacing: 0) {
                sidebar
                Divider()
                    .opacity(colorScheme == .dark ? 0.28 : 0.42)
                detailPane
            }
        }
        .frame(minWidth: 920, idealWidth: 1200, minHeight: 680, idealHeight: 820)
        .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
                .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
        }
        .onAppear {
            if !hasCompletedOnboarding {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showOnboarding = true
                }
            }
        }
    }

    private var premiumBackground: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.055, green: 0.06, blue: 0.068), Color(red: 0.10, green: 0.105, blue: 0.115)]
                    : [Color(red: 1.0, green: 0.975, blue: 0.90), Color(red: 0.94, green: 0.955, blue: 0.965)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AppTheme.logoYellow.opacity(colorScheme == .dark ? 0.16 : 0.22))
                .blur(radius: 70)
                .frame(width: 300, height: 300)
                .offset(x: -310, y: -260)

            Circle()
                .fill(AppTheme.cyan.opacity(colorScheme == .dark ? 0.12 : 0.18))
                .blur(radius: 80)
                .frame(width: 360, height: 360)
                .offset(x: 370, y: 260)
        }
        .ignoresSafeArea()
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 12) {
                DictatorLogoMark(size: 82, cornerRadius: 18)

                VStack(spacing: 4) {
                    Text("Dictator-md")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Local AI Dictation")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 54)
            .padding(.bottom, 30)

            ForEach(SettingsSection.allCases) { section in
                Button {
                    DebugLog.shared.log("[SettingsView] sidebar selected \(section.displayName)")
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedSection = section
                    }
                } label: {
                    SidebarRow(
                        title: section.displayName,
                        icon: section.icon,
                        isSelected: selectedSection == section,
                        colorScheme: colorScheme
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            SidebarSystemStatusCard(engine: engine, settings: settings, colorScheme: colorScheme)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

            Button {
                showOnboarding = true
            } label: {
                Label("Setup Guide", systemImage: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? AppTheme.logoYellowSoft : AppTheme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.logoYellow.opacity(colorScheme == .dark ? 0.13 : 0.22))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            HStack(spacing: 6) {
                Circle()
                    .fill(engine.isModelLoaded ? AppTheme.readyGreen : .orange)
                    .frame(width: 7, height: 7)
                Text(engine.state == .idle ? (engine.isModelLoaded ? "Ready" : "Loading...") : engine.state.rawValue.capitalized)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(width: 220)
        .background(
            colorScheme == .dark
                ? Color.black.opacity(0.28)
                : Color.white.opacity(0.50)
        )
    }

    // MARK: - Detail Pane

    private var detailPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 18) {
                        sectionTitleBlock
                        Spacer(minLength: 16)
                        headerAccessory
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        sectionTitleBlock
                        headerAccessory
                    }
                }
                .padding(.bottom, selectedSection == .dashboard ? 24 : 18)

                switch selectedSection {
                case .dashboard:
                    DashboardSection(memory: memory, settings: settings, engine: engine, colorScheme: colorScheme)
                case .general:
                    GeneralSection(settings: settings, engine: engine, colorScheme: colorScheme)
                case .model:
                    ModelSection(settings: settings, modelManager: modelManager, engine: engine, colorScheme: colorScheme)
                case .history:
                    HistorySection(memory: memory, colorScheme: colorScheme)
                case .vocabulary:
                    VocabularySection(settings: settings, colorScheme: colorScheme)
                case .protocols:
                    ProtocolsSection(colorScheme: colorScheme)
                case .permissions:
                    PermissionsSection(permissions: permissions, colorScheme: colorScheme)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sectionTitleBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(selectedSection.displayName)
                .font(.system(size: selectedSection == .dashboard ? 28 : 24, weight: .bold, design: .rounded))
            Text(sectionSubtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var headerAccessory: some View {
        if selectedSection == .dashboard {
            DashboardTopController(settings: settings, engine: engine, colorScheme: colorScheme)
        } else {
            HStack(spacing: 8) {
                Circle()
                    .fill(engine.state == .recording ? .red : (engine.isModelLoaded ? AppTheme.readyGreen : .orange))
                    .frame(width: 8, height: 8)
                Text(engine.state == .idle ? (engine.isModelLoaded ? "Ready" : "Loading") : engine.state.rawValue.capitalized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(colorScheme == .dark ? Color.white.opacity(0.07) : Color.white.opacity(0.70)))
        }
    }

    private var sectionSubtitle: String {
        switch selectedSection {
        case .dashboard: "Your local dictation assistant at a glance."
        case .general: "Hotkey, language, microphone, and AI voice intelligence."
        case .model: "Offline transcription engines and performance controls."
        case .history: "Searchable dictation history and activity over time."
        case .vocabulary: "Self-learning terms and custom project language."
        case .protocols: "Core reliability rules for future development."
        case .permissions: "System access diagnostics for microphone and typing."
        }
    }
}

// MARK: - Sidebar Row

private struct SidebarRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? AppTheme.ink : .secondary)
                .frame(width: 24, height: 24)
                .background(
                    isSelected
                        ? AnyShapeStyle(AppTheme.selectedGradient)
                        : AnyShapeStyle(Color.clear)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? (colorScheme == .dark ? AppTheme.logoYellowSoft : AppTheme.ink) : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected
                ? RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? AppTheme.logoYellow.opacity(0.13) : AppTheme.logoYellow.opacity(0.22))
                : nil
        )
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}

private struct SidebarSystemStatusCard: View {
    let engine: DictationEngine
    @ObservedObject var settings: AppSettings
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Circle()
                    .fill(engine.isModelLoaded ? AppTheme.readyGreen : .orange)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(engine.isModelLoaded ? "System Ready" : "System Loading")
                        .font(.system(size: 13, weight: .semibold))
                    Text("All services operational")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Divider().opacity(0.35)

            HStack(spacing: 10) {
                Image(systemName: "cpu")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local Model")
                        .font(.system(size: 12, weight: .semibold))
                    Text(settings.selectedModel)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(engine.isModelLoaded ? AppTheme.readyGreen : .orange)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color.white.opacity(0.045) : Color.white.opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Card

private struct SettingsCard<Content: View>: View {
    let colorScheme: ColorScheme
    @ViewBuilder let content: Content
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color.white.opacity(isHovering ? 0.078 : 0.055) : Color.white.opacity(isHovering ? 0.82 : 0.72))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: isHovering ? 16 : 14, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isHovering
                        ? AppTheme.logoYellow.opacity(colorScheme == .dark ? 0.24 : 0.34)
                        : (colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.72)),
                    lineWidth: isHovering ? 0.9 : 0.7
                )
        )
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.logoYellow.opacity(isHovering ? 0.10 : 0.045), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .allowsHitTesting(false)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovering = hovering
            }
        }
    }
}

private struct CardHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Dashboard Section

private struct DashboardSection: View {
    @ObservedObject var memory: DictationMemory
    @ObservedObject var settings: AppSettings
    let engine: DictationEngine
    let colorScheme: ColorScheme
    @State private var availableWidth: CGFloat = 0

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(spacing: 16) {
            metricCards
            dashboardPanels

            ConceptPrivacyStrip(colorScheme: colorScheme)
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        updateAvailableWidth(proxy.size.width)
                    }
                    .onChange(of: proxy.size.width) { _, width in
                        updateAvailableWidth(width)
                    }
            }
        )
    }

    @ViewBuilder
    private var metricCards: some View {
        let cards = [
            DashboardMetricDescriptor(title: "Today's Words", value: formatted(wordsToday), trend: "+18% vs yesterday", icon: "doc.text", color: AppTheme.readyGreen),
            DashboardMetricDescriptor(title: "Weekly Words", value: formatted(wordsThisWeek), trend: "+12% vs last week", icon: "calendar", color: Color(red: 0.30, green: 0.48, blue: 1.0)),
            DashboardMetricDescriptor(title: "Average WPM", value: "\(averageWPMThisWeek)", trend: "+6% vs last week", icon: "gauge.with.dots.needle.67percent", color: Color(red: 0.64, green: 0.36, blue: 0.95)),
            DashboardMetricDescriptor(title: "New Vocabulary", value: "\(newTermsThisWeek)", trend: "+8% vs last week", icon: "book", color: Color(red: 1.0, green: 0.66, blue: 0.12))
        ]

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: metricColumnCount), spacing: 12) {
            ForEach(cards) { card in
                ConceptMetricCard(descriptor: card, colorScheme: colorScheme)
            }
        }
    }

    @ViewBuilder
    private var dashboardPanels: some View {
        if availableWidth >= 900 {
            HStack(alignment: .top, spacing: 12) {
                ConceptWeeklyActivityCard(history: memory.history, colorScheme: colorScheme)
                    .frame(maxWidth: .infinity)

                ConceptSystemCard(
                    selectedModel: settings.selectedModel,
                    language: settings.dictationLanguage,
                    modelLoaded: engine.isModelLoaded,
                    colorScheme: colorScheme
                )
                .frame(width: 270)

                ConceptRecentDictationsCard(history: Array(memory.history.prefix(4)), colorScheme: colorScheme)
                    .frame(width: 320)
            }
        } else if availableWidth >= 620 {
            VStack(spacing: 12) {
                ConceptWeeklyActivityCard(history: memory.history, colorScheme: colorScheme)
                HStack(alignment: .top, spacing: 12) {
                    ConceptSystemCard(
                        selectedModel: settings.selectedModel,
                        language: settings.dictationLanguage,
                        modelLoaded: engine.isModelLoaded,
                        colorScheme: colorScheme
                    )

                    ConceptRecentDictationsCard(history: Array(memory.history.prefix(4)), colorScheme: colorScheme)
                }
            }
        } else {
            VStack(spacing: 12) {
                ConceptWeeklyActivityCard(history: memory.history, colorScheme: colorScheme)
                ConceptSystemCard(
                    selectedModel: settings.selectedModel,
                    language: settings.dictationLanguage,
                    modelLoaded: engine.isModelLoaded,
                    colorScheme: colorScheme
                )
                ConceptRecentDictationsCard(history: Array(memory.history.prefix(4)), colorScheme: colorScheme)
            }
        }
    }

    private var metricColumnCount: Int {
        if availableWidth >= 860 { return 4 }
        if availableWidth >= 520 { return 2 }
        return 1
    }

    private func updateAvailableWidth(_ width: CGFloat) {
        guard abs(width - availableWidth) > 1 else { return }
        DispatchQueue.main.async {
            availableWidth = width
        }
    }

    private var statusTitle: String {
        switch engine.state {
        case .idle:
            return engine.isModelLoaded ? "Ready to Dictate" : "Loading Engine"
        case .recording:
            return "Listening"
        case .processing:
            return "Transcribing"
        case .typing:
            return "Pasting Text"
        }
    }

    private var wordsToday: Int {
        words(since: calendar.startOfDay(for: Date()))
    }

    private var wordsThisWeek: Int {
        words(since: calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date()))
    }

    private var newTermsToday: Int {
        learnedTerms(since: calendar.startOfDay(for: Date()))
    }

    private var newTermsThisWeek: Int {
        learnedTerms(since: calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date()))
    }

    private var averageWPMThisWeek: Int {
        averageWPM(since: calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date()))
    }

    private var recentLearnedTerms: [LearnedTerm] {
        Array(memory.learnedTerms.sorted { $0.lastSeen > $1.lastSeen }.prefix(6))
    }

    private var weeklyBuckets: [DailyWordBucket] {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? Date()
        return dailyBuckets(startingAt: weekStart, endingAt: weekEnd, calendar: calendar, history: memory.history)
    }

    private var weeklyDictations: Int {
        weeklyBuckets.reduce(0) { $0 + $1.dictations }
    }

    private var shortLanguageLabel: String {
        switch settings.dictationLanguage {
        case .auto: return "Auto"
        case .english: return "EN"
        case .bulgarian: return "BG"
        }
    }

    private func words(since start: Date) -> Int {
        memory.history
            .filter { $0.timestamp >= start }
            .reduce(0) { $0 + $1.wordCount }
    }

    private func learnedTerms(since start: Date) -> Int {
        memory.learnedTerms.filter { ($0.firstSeen ?? $0.lastSeen) >= start }.count
    }

    private func averageWPM(since start: Date) -> Int {
        let items = memory.history.filter { $0.timestamp >= start && $0.audioDuration > 0.5 }
        let totalWords = items.reduce(0) { $0 + $1.wordCount }
        let totalSeconds = items.reduce(0.0) { $0 + $1.audioDuration }
        guard totalWords > 0, totalSeconds > 0 else { return 0 }
        return Int((Double(totalWords) / totalSeconds * 60).rounded())
    }

    private func formatted(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private struct FloatingNodePreview: View {
    let language: AppSettings.DictationLanguage
    let colorScheme: ColorScheme
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 7) {
            Capsule()
                .fill(AppTheme.readyGreen)
                .frame(width: 34, height: 5)
                .opacity(pulse ? 0.55 : 1.0)

            Text(shortLanguage)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(colorScheme == .dark ? AppTheme.logoYellowSoft : AppTheme.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(AppTheme.logoYellow.opacity(colorScheme == .dark ? 0.15 : 0.28)))

            Image(systemName: "mic.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 26, height: 26)
                .background(Circle().fill(AppTheme.logoYellow))

            Image(systemName: "arrow.up.forward.app.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04)))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(colorScheme == .dark ? Color.black.opacity(0.34) : Color.white.opacity(0.78))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.26 : 0.10), radius: 16, y: 8)
        )
        .overlay(
            Capsule()
                .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.85), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var shortLanguage: String {
        switch language {
        case .auto: "AUTO"
        case .english: "EN"
        case .bulgarian: "BG"
        }
    }
}

private struct ConceptPanel<Content: View>: View {
    let colorScheme: ColorScheme
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color.white.opacity(0.055) : Color.white.opacity(0.72))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 14, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.72), lineWidth: 1)
        )
    }
}

private struct DashboardTopController: View {
    @ObservedObject var settings: AppSettings
    let engine: DictationEngine
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 11) {
            languageChip(.auto, "Auto")
            languageChip(.english, "EN")
            languageChip(.bulgarian, "BG")

            Button {
                engine.toggleDictationFromUI()
            } label: {
                Image(systemName: micIcon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(engine.state == .idle ? AppTheme.ink : .white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(statusColor))
                    .overlay(Circle().stroke(Color.white.opacity(0.20), lineWidth: 3))
            }
            .buttonStyle(.plain)
            .help(engine.state == .recording ? "Stop dictation" : "Start dictation")

            Group {
                if engine.state == .processing || engine.state == .typing {
                    DashboardLoadingDots(color: statusColor, dotSize: 4.5, spacing: 4)
                        .frame(width: 31, height: 31)
                } else {
                    Image(systemName: engine.state == .recording ? "waveform" : "waveform.path")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(statusColor.opacity(0.85))
                        .frame(width: 31, height: 31)
                }
            }

            Button {
                SettingsWindowController.shared.show(engine: engine)
            } label: {
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 31, height: 31)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(colorScheme == .dark ? 0.055 : 0.56)))
            }
            .buttonStyle(.plain)
            .help("Open Dictator-md")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color.black.opacity(0.36) : Color.white.opacity(0.80))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.65), lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel("Floating dictation controller preview")
    }

    private func languageChip(_ language: AppSettings.DictationLanguage, _ label: String) -> some View {
        Button {
            settings.dictationLanguage = language
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(settings.dictationLanguage == language ? AppTheme.logoYellow : .secondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(settings.dictationLanguage == language ? AppTheme.logoYellow.opacity(0.13) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help("Set language to \(language.label)")
    }

    private var statusColor: Color {
        switch engine.state {
        case .idle: return engine.isModelLoaded ? AppTheme.logoYellow : .orange
        case .recording: return .red
        case .processing: return AppTheme.cyan
        case .typing: return AppTheme.cyan
        }
    }

    private var micIcon: String {
        switch engine.state {
        case .idle: return "mic.fill"
        case .recording: return "stop.fill"
        case .processing: return "brain.head.profile.fill"
        case .typing: return "text.cursor"
        }
    }
}

private struct DashboardLoadingDots: View {
    let color: Color
    let dotSize: CGFloat
    let spacing: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: spacing) {
                ForEach(0..<3, id: \.self) { index in
                    let phase = (sin((time * 5.2) - Double(index) * 0.72) + 1) / 2
                    Circle()
                        .fill(color.opacity(0.36 + phase * 0.64))
                        .frame(width: dotSize, height: dotSize)
                        .offset(y: CGFloat(-phase * 2.4))
                        .scaleEffect(0.82 + phase * 0.24)
                }
            }
        }
    }
}

private struct DashboardMetricDescriptor: Identifiable {
    var id: String { title }
    let title: String
    let value: String
    let trend: String
    let icon: String
    let color: Color
}

private struct ConceptMetricCard: View {
    let descriptor: DashboardMetricDescriptor
    let colorScheme: ColorScheme

    var body: some View {
        ConceptPanel(colorScheme: colorScheme) {
            HStack(spacing: 12) {
                Image(systemName: descriptor.icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(descriptor.color)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(descriptor.color.opacity(0.14)))

                VStack(alignment: .leading, spacing: 6) {
                    Text(descriptor.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(descriptor.value)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Label(descriptor.trend, systemImage: "arrow.up")
                        .font(.system(size: descriptor.trend.contains("%") ? 12 : 10, weight: .semibold))
                        .foregroundStyle(AppTheme.readyGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(minHeight: 104, maxHeight: 104)
    }
}

private struct HistoryMetricCard: View {
    let descriptor: DashboardMetricDescriptor
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 9) {
                Image(systemName: descriptor.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(descriptor.color)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(descriptor.color.opacity(0.15)))

                Text(descriptor.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Text(descriptor.value)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Label(descriptor.trend, systemImage: "arrow.up")
                .font(.system(size: descriptor.trend.contains("%") ? 12 : 11, weight: .semibold))
                .foregroundStyle(AppTheme.logoYellow)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, maxHeight: 112, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color.white.opacity(0.055) : Color.white.opacity(0.72))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.05), radius: 11, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.72), lineWidth: 1)
        )
    }
}

private enum ActivityRange: String, CaseIterable, Identifiable {
    case thisWeek = "This week"
    case lastSevenDays = "Last 7 days"
    case thisMonth = "This month"

    var id: String { rawValue }
}

private struct ConceptWeeklyActivityCard: View {
    let history: [DictationHistoryItem]
    let colorScheme: ColorScheme
    @State private var focusedDay: Date?
    @State private var selectedRange: ActivityRange = .thisWeek

    private var calendar: Calendar { .current }
    private var days: [DailyWordBucket] {
        switch selectedRange {
        case .thisWeek:
            let start = mondayStart(for: Date())
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? Date()
            return dailyBuckets(startingAt: start, endingAt: end, calendar: calendar, history: history)
        case .lastSevenDays:
            let today = calendar.startOfDay(for: Date())
            let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
            return dailyBuckets(startingAt: start, endingAt: today, calendar: calendar, history: history)
        case .thisMonth:
            guard let interval = calendar.dateInterval(of: .month, for: Date()) else { return [] }
            let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? Date()
            return dailyBuckets(startingAt: interval.start, endingAt: end, calendar: calendar, history: history)
        }
    }

    private var maxWords: Int {
        max(days.map(\.words).max() ?? 0, 1)
    }

    private var monthWeeks: [[DailyWordBucket]] {
        monthWeekBuckets(containing: Date(), calendar: calendar, history: history)
    }

    var body: some View {
        ConceptPanel(colorScheme: colorScheme) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Text(selectedRange == .thisMonth ? "Monthly Activity" : "Weekly Activity")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    rangeButtons
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(selectedRange == .thisMonth ? "Monthly Activity" : "Weekly Activity")
                        .font(.system(size: 15, weight: .semibold))
                    rangeButtons
                }
            }

            activityBody
        }
        .frame(minHeight: selectedRange == .thisMonth ? 430 : 330)
    }

    @ViewBuilder
    private var activityBody: some View {
        if selectedRange == .thisMonth {
            MonthActivityGrid(
                weeks: monthWeeks,
                selectedMonth: Date(),
                colorScheme: colorScheme
            )
            .padding(.top, 4)
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .trailing) {
                    Text(axisLabel(1.0))
                    Spacer()
                    Text(axisLabel(0.66))
                    Spacer()
                    Text(axisLabel(0.33))
                    Spacer()
                    Text("0")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(height: 210)

                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(days) { day in
                        dayColumn(day)
                    }
                }
                .frame(height: 230)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                        .offset(y: -36)
                }
            }
            .transition(.opacity)
        }
    }

    private var rangeButtons: some View {
        HStack(spacing: 6) {
            ForEach(ActivityRange.allCases) { range in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        selectedRange = range
                        focusedDay = nil
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedRange == range ? AppTheme.logoYellow.opacity(0.18) : Color.white.opacity(colorScheme == .dark ? 0.055 : 0.48))
                        )
                        .foregroundStyle(selectedRange == range ? AppTheme.logoYellowSoft : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dayColumn(_ day: DailyWordBucket) -> some View {
        let isToday = day.date == calendar.startOfDay(for: Date())
        let isFocused = focusedDay == day.date
        return VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text(compactWords(day.words))
                    .font(.system(size: 10, weight: isFocused ? .bold : .semibold))
                Text("\(day.dictations) captures")
                    .font(.system(size: 8, weight: .medium))
                    .opacity(isFocused ? 1 : 0)
            }
            .foregroundStyle(isFocused ? AppTheme.logoYellowSoft : .secondary)
            .frame(height: 29)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(Capsule().fill(isFocused ? AppTheme.logoYellow.opacity(0.12) : .clear))

            RoundedRectangle(cornerRadius: isFocused ? 8 : 6)
                .fill(isToday || isFocused ? AppTheme.selectedGradient : LinearGradient(colors: [AppTheme.logoYellow.opacity(0.35), AppTheme.logoYellow.opacity(0.12)], startPoint: .top, endPoint: .bottom))
                .frame(width: 29, height: max(16, CGFloat(day.words) / CGFloat(maxWords) * 120))
                .overlay(
                    RoundedRectangle(cornerRadius: isFocused ? 8 : 6)
                        .stroke(AppTheme.logoYellow.opacity(isFocused ? 0.52 : 0), lineWidth: 1)
                )
                .shadow(color: AppTheme.logoYellow.opacity(isFocused || isToday ? 0.24 : 0.10), radius: isFocused ? 8 : 5)

            VStack(spacing: 1) {
                Text(Self.dayFormatter.string(from: day.date))
                    .font(.system(size: 10, weight: isFocused ? .bold : .medium))
                Text(Self.dateFormatter.string(from: day.date))
                    .font(.system(size: 8, weight: .medium))
                    .monospacedDigit()
            }
            .foregroundStyle(isFocused ? AppTheme.logoYellowSoft : .secondary)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                focusedDay = hovering ? day.date : (focusedDay == day.date ? nil : focusedDay)
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                focusedDay = focusedDay == day.date ? nil : day.date
            }
        }
        .help("\(compactWords(day.words)) words, \(day.dictations) dictations")
    }

    private func compactWords(_ words: Int) -> String {
        if words >= 1000 {
            return String(format: "%.1fK", Double(words) / 1000.0)
        }
        return "\(words)"
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private static let dayNumberFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    private func axisLabel(_ ratio: Double) -> String {
        compactWords(Int((Double(maxWords) * ratio).rounded()))
    }

    private func mondayStart(for date: Date) -> Date {
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start)
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: start) ?? start
    }
}

private struct ConceptSystemCard: View {
    let selectedModel: String
    let language: AppSettings.DictationLanguage
    let modelLoaded: Bool
    let colorScheme: ColorScheme

    var body: some View {
        ConceptPanel(colorScheme: colorScheme) {
            VStack(spacing: 0) {
                ConceptSystemRow(icon: "cpu", title: "Local Model", subtitle: selectedModel, status: modelLoaded ? "Loaded" : "Loading", statusColor: modelLoaded ? AppTheme.readyGreen : .orange)
                Divider().opacity(0.30)
                ConceptSystemRow(icon: "globe", title: "Language Mode", subtitle: languageSubtitle, status: shortLanguage, statusColor: AppTheme.logoYellow)
                Divider().opacity(0.30)
                ConceptSystemRow(icon: "externaldrive", title: "Model Context", subtitle: "4,096 tokens", status: nil, statusColor: .secondary)
                Divider().opacity(0.30)
                ConceptSystemRow(icon: "waveform.path", title: "Compute", subtitle: "Metal (GPU)", status: "Active", statusColor: AppTheme.readyGreen)
            }

            Button {
                // The actual Control section remains available in the sidebar.
            } label: {
                HStack {
                    Label("Control Center", systemImage: "shield.checkered")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 14, weight: .medium))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(colorScheme == .dark ? 0.055 : 0.50)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 330)
    }

    private var shortLanguage: String {
        switch language {
        case .auto: return "Auto"
        case .english: return "EN"
        case .bulgarian: return "BG"
        }
    }

    private var languageSubtitle: String {
        switch language {
        case .auto: return "Auto Detect"
        case .english: return "English"
        case .bulgarian: return "Bulgarian"
        }
    }
}

private struct ConceptSystemRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let status: String?
    let statusColor: Color

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let status {
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(status)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
            }
        }
        .padding(.vertical, 13)
    }
}

private struct ConceptRecentDictationsCard: View {
    let history: [DictationHistoryItem]
    let colorScheme: ColorScheme

    var body: some View {
        ConceptPanel(colorScheme: colorScheme) {
            HStack {
                Text("Recent Dictations")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("View all") {}
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            if history.isEmpty {
                EmptyStateLine(icon: "mic", text: "Recent dictations will appear here.")
            } else {
                VStack(spacing: 8) {
                    ForEach(history) { item in
                        ConceptRecentDictationRow(item: item, colorScheme: colorScheme)
                    }
                }
            }

            Button {
            } label: {
                Label("Start New Dictation", systemImage: "mic")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(colorScheme == .dark ? 0.055 : 0.56)))
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 330)
    }
}

private struct ConceptRecentDictationRow: View {
    let item: DictationHistoryItem
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "mic.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(item.wordCount > 180 ? AppTheme.readyGreen : AppTheme.logoYellow)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text("\(relativeTime) • \(item.wordCount) words")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(item.text)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "ellipsis")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(colorScheme == .dark ? 0.035 : 0.46)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var title: String {
        if item.appName.isEmpty {
            return "Dictation"
        }
        return item.appName == "Codex" ? "Project update and roadmap" : "\(item.appName) dictation"
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: item.timestamp, relativeTo: Date())
    }
}

private struct ConceptPrivacyStrip: View {
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 9).fill(AppTheme.readyGreen))

            VStack(alignment: .leading, spacing: 2) {
                Text("Privacy First")
                    .font(.system(size: 14, weight: .semibold))
                Text("All processing happens locally. Your data never leaves this device.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
            } label: {
                Label("Learn More", systemImage: "arrow.up.forward")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color.white.opacity(0.055) : Color.white.opacity(0.68))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.75), lineWidth: 1)
        )
    }
}

private struct DashboardHeroCard: View {
    let statusTitle: String
    let state: DictationState
    let wordsToday: Int
    let averageWPM: Int
    let colorScheme: ColorScheme
    @State private var shimmer = false

    var body: some View {
        heroCard
            .frame(minHeight: 214)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.80), lineWidth: 1)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                    shimmer = true
                }
            }
    }

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            heroBase
            heroGlow
            heroContent
        }
    }

    private var heroBase: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color.white.opacity(0.09), Color.white.opacity(0.045)]
                        : [Color.white.opacity(0.84), Color.white.opacity(0.56)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.26 : 0.07), radius: 18, y: 10)
    }

    private var heroGlow: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    RadialGradient(
                        colors: [AppTheme.logoYellow.opacity(colorScheme == .dark ? 0.22 : 0.28), .clear],
                        center: .topLeading,
                        startRadius: 20,
                        endRadius: 280
                    )
                )
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    RadialGradient(
                        colors: [AppTheme.cyan.opacity(colorScheme == .dark ? 0.14 : 0.18), .clear],
                        center: .bottomTrailing,
                        startRadius: 30,
                        endRadius: 320
                    )
                )
        }
    }

    private var heroContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            heroHeader
            HStack(spacing: 10) {
                HeroMicroMetric(title: "Today", value: "\(wordsToday)", suffix: "words")
                HeroMicroMetric(title: "Speed", value: "\(averageWPM)", suffix: "wpm")
                HeroMicroMetric(title: "Mode", value: "Local", suffix: "offline")
            }
            HStack(spacing: 8) {
                FeaturePill(icon: "lock.fill", text: "private", color: AppTheme.readyGreen, colorScheme: colorScheme)
                FeaturePill(icon: "globe.europe.africa.fill", text: "EN / BG", color: AppTheme.cyan, colorScheme: colorScheme)
                FeaturePill(icon: "sparkles", text: "voice intelligence", color: AppTheme.logoYellow, colorScheme: colorScheme)
            }
        }
        .padding(22)
    }

    private var heroHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            DictatorLogoMark(size: 70)
                .scaleEffect(shimmer ? 1.015 : 1.0)
            VStack(alignment: .leading, spacing: 7) {
                Label(statusTitle, systemImage: state == .recording ? "waveform" : "mic.fill")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text("Private local voice layer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(state == .idle ? "Online" : state.rawValue.capitalized)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(colorScheme == .dark ? Color.black.opacity(0.22) : Color.white.opacity(0.58)))
        }
    }

    private var statusColor: Color {
        switch state {
        case .idle: return AppTheme.readyGreen
        case .recording: return .red
        case .processing: return AppTheme.cyan
        case .typing: return AppTheme.logoYellow
        }
    }
}

private struct HeroMicroMetric: View {
    let title: String
    let value: String
    let suffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(suffix)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.13)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

private struct DashboardStatusPanel: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color
    let colorScheme: ColorScheme

    var body: some View {
        SettingsCard(colorScheme: colorScheme) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 9).fill(tint))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct DashboardFloatingNodeCard: View {
    let language: AppSettings.DictationLanguage
    let colorScheme: ColorScheme

    var body: some View {
        SettingsCard(colorScheme: colorScheme) {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader("Floating Node", subtitle: "Overlay controller")
                FloatingNodePreview(language: language, colorScheme: colorScheme)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct DashboardMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 28, height: 28)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                Spacer()
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color.white.opacity(0.055) : Color.white.opacity(0.92))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.055), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(colorScheme == .dark ? 0.18 : 0.28), lineWidth: 0.7)
        )
    }
}

private struct DailyWordBucket: Identifiable {
    var id: Date { date }
    let date: Date
    let words: Int
    let dictations: Int
    let audioDuration: Double

    var averageWPM: Int {
        guard words > 0, audioDuration > 0 else { return 0 }
        return Int((Double(words) / audioDuration * 60).rounded())
    }
}

private func dailyBuckets(
    startingAt start: Date,
    endingAt end: Date,
    calendar: Calendar,
    history: [DictationHistoryItem]
) -> [DailyWordBucket] {
    let startDay = calendar.startOfDay(for: start)
    let endDay = calendar.startOfDay(for: end)
    guard startDay <= endDay else { return [] }

    var buckets: [DailyWordBucket] = []
    var day = startDay
    while day <= endDay {
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        let items = history.filter { $0.timestamp >= day && $0.timestamp < nextDay }
        buckets.append(
            DailyWordBucket(
                date: day,
                words: items.reduce(0) { $0 + $1.wordCount },
                dictations: items.count,
                audioDuration: items.reduce(0.0) { $0 + $1.audioDuration }
            )
        )
        day = nextDay
    }
    return buckets
}

private func monthWeekBuckets(
    containing date: Date,
    calendar: Calendar,
    history: [DictationHistoryItem]
) -> [[DailyWordBucket]] {
    guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }
    let monthStart = monthInterval.start
    let monthEnd = calendar.date(byAdding: .second, value: -1, to: monthInterval.end) ?? monthInterval.end
    let firstWeekStart = calendar.dateInterval(of: .weekOfYear, for: monthStart)?.start ?? calendar.startOfDay(for: monthStart)
    let lastWeekStart = calendar.dateInterval(of: .weekOfYear, for: monthEnd)?.start ?? calendar.startOfDay(for: monthEnd)

    var weeks: [[DailyWordBucket]] = []
    var weekStart = firstWeekStart
    while weekStart <= lastWeekStart {
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        weeks.append(dailyBuckets(startingAt: weekStart, endingAt: weekEnd, calendar: calendar, history: history))
        guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: weekStart), nextWeek > weekStart else { break }
        weekStart = nextWeek
    }
    return weeks
}

private struct WeeklyWordBars: View {
    let days: [DailyWordBucket]
    let colorScheme: ColorScheme

    var body: some View {
        ConceptWeeklyActivityCard(history: DictationMemory.shared.history, colorScheme: colorScheme)
            .frame(minHeight: 330)
    }
}

private struct DashboardTermRow: View {
    let term: LearnedTerm

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.readyGreen)
            Text(term.term)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
            Spacer()
            Text("\(term.count)x")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

private struct FeaturePill: View {
    let icon: String
    let text: String
    let color: Color
    let colorScheme: ColorScheme

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(colorScheme == .dark ? 0.16 : 0.22))
            )
            .foregroundStyle(colorScheme == .dark ? color : AppTheme.ink)
    }
}

private struct CompactHistoryRow: View {
    let item: DictationHistoryItem
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.appName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(item.wordCount) words")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            Text(item.text)
                .font(.system(size: 12))
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color.black.opacity(0.18) : Color.black.opacity(0.035))
        )
    }
}

// MARK: - General Section

private struct GeneralSection: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var audioDevices: AudioDeviceManager = .shared
    let engine: DictationEngine
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(colorScheme: colorScheme) {
                CardHeader(
                    "Hotkey",
                    subtitle: settings.hotkeyMode == .pushToTalk
                        ? "Hold to dictate, or double-tap to record hands-free"
                        : "Press to start, press to stop — easier on the wrists"
                )
                HotkeyRecorder(keyCode: $settings.hotkeyKeyCode, colorScheme: colorScheme)

                Picker("Mode", selection: $settings.hotkeyMode) {
                    Text("Push-to-talk").tag(AppSettings.HotkeyMode.pushToTalk)
                    Text("Toggle — easier on the wrists").tag(AppSettings.HotkeyMode.toggle)
                }
                .pickerStyle(.segmented)
                .font(.system(size: 13))
                .accessibilityLabel("Hotkey activation mode")

                if settings.hotkeyMode == .toggle {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11))
                        Text("No need to hold the key while you talk — friendlier for long dictations and anyone managing carpal tunnel or RSI.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Hold duration to activate")
                                .font(.system(size: 13))
                            Spacer()
                            Text(String(format: "%.1fs", settings.toggleHoldDuration))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $settings.toggleHoldDuration, in: 0.5...3.0, step: 0.1)
                        Text("How long to hold the hotkey to start or stop. Longer values prevent accidental activation when the key is used in shortcuts.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }

            SettingsCard(colorScheme: colorScheme) {
                CardHeader("Language", subtitle: "Recognition language for local transcription")
                Picker("Recognition", selection: $settings.dictationLanguage) {
                    ForEach(AppSettings.DictationLanguage.allCases) { language in
                        Text(language.label).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .font(.system(size: 13))

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "globe.europe.africa.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))
                    Text(languageHint)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }

            SettingsCard(colorScheme: colorScheme) {
                CardHeader("Microphone", subtitle: "Audio input device for recording")
                Picker("Input device", selection: Binding(
                    get: { settings.selectedAudioDeviceUID ?? "" },
                    set: { settings.selectedAudioDeviceUID = $0.isEmpty ? nil : $0 }
                )) {
                    Text("System Default").tag("")
                    ForEach(audioDevices.inputDevices) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                .font(.system(size: 13))
                .onAppear { audioDevices.refreshDevices() }
            }

            SettingsCard(colorScheme: colorScheme) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [AppTheme.logoYellow, AppTheme.cyan.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Image(systemName: "sparkles")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(AppTheme.ink)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center) {
                            CardHeader("Voice Intelligence", subtitle: "Experimental speech-aware punctuation")
                            Spacer()
                            Toggle("", isOn: $settings.intonationFormattingEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }

                        Text("Uses spoken punctuation commands plus short-phrase audio cues like pitch rise and emphasis. Keep it off for strict raw dictation; turn it on to test more natural question and emphasis punctuation.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            FeaturePill(icon: "questionmark.circle.fill", text: "questions", color: AppTheme.cyan, colorScheme: colorScheme)
                            FeaturePill(icon: "exclamationmark.circle.fill", text: "emphasis", color: AppTheme.logoYellow, colorScheme: colorScheme)
                            FeaturePill(icon: "text.alignleft", text: "spoken punctuation", color: AppTheme.readyGreen, colorScheme: colorScheme)
                        }
                    }
                }
            }

            SettingsCard(colorScheme: colorScheme) {
                CardHeader("Preferences")
                HStack {
                    Label("Appearance", systemImage: "circle.lefthalf.filled")
                        .font(.system(size: 13))
                    Spacer()
                    Picker("Appearance", selection: $settings.appearanceMode) {
                        ForEach(AppSettings.AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 210)
                    .labelsHidden()
                }
                Toggle("Show floating node", isOn: $settings.floatingNodeEnabled)
                    .font(.system(size: 13))
                    .onChange(of: settings.floatingNodeEnabled) { _, _ in
                        FloatingNodeController.shared.configure(engine: engine)
                    }
                Toggle("Auto-correct grammar & formatting", isOn: $settings.grammarCorrectionEnabled)
                    .font(.system(size: 13))
                Toggle("Convert number words to digits", isOn: $settings.numberConversionEnabled)
                    .font(.system(size: 13))
                Toggle("Sound feedback", isOn: $settings.soundFeedbackEnabled)
                    .font(.system(size: 13))
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .font(.system(size: 13))
                    .onChange(of: settings.launchAtLogin) { _, newValue in
                        LaunchAtLoginHelper.setEnabled(newValue)
                    }
            }
        }
    }

    private var languageHint: String {
        switch settings.dictationLanguage {
        case .auto:
            "Auto now only switches between English and Bulgarian. It will not allow Russian as a detected output language."
        case .bulgarian:
            "Forces Bulgarian recognition and Cyrillic output, with a guard against Russian-looking output."
        case .english:
            "Forces English recognition and blocks Cyrillic output, so English dictation stays in Latin characters."
        }
    }
}

// MARK: - Hotkey Recorder

private struct HotkeyRecorder: View {
    @Binding var keyCode: Int
    let colorScheme: ColorScheme
    @State private var isRecording = false
    @State private var eventMonitors: [Any] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Keycap display
            Button(action: { toggleRecording() }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                isRecording
                                    ? AppTheme.selectedGradient
                                    : LinearGradient(
                                        colors: colorScheme == .dark
                                            ? [Color.white.opacity(0.12), Color.white.opacity(0.06)]
                                            : [Color.white, Color(.controlBackgroundColor)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        isRecording ? AppTheme.logoYellow.opacity(0.55) : (colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.12)),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.1), radius: 1, y: 1)
                            .frame(height: 38)

                        if isRecording {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 6, height: 6)
                                    .opacity(0.8)
                                Text("Press any key...")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppTheme.ink)
                            }
                        } else {
                            Text(keyName(for: keyCode))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                    }

                    if !isRecording {
                        Text("Click to change")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)

            // Quick pick pills
            HStack(spacing: 6) {
                ForEach(presetKeys, id: \.code) { preset in
                    Button {
                        keyCode = preset.code
                        stopRecording()
                    } label: {
                        Text(preset.name)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(keyCode == preset.code
                                        ? AppTheme.logoYellow.opacity(0.18)
                                        : (colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(keyCode == preset.code ? AppTheme.logoYellow.opacity(0.55) : Color.clear, lineWidth: 1)
                            )
                            .foregroundStyle(keyCode == preset.code ? (colorScheme == .dark ? AppTheme.logoYellowSoft : AppTheme.ink) : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onDisappear { stopRecording() }
    }

    private func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        isRecording = true
        let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            keyCode = Int(event.keyCode)
            stopRecording()
            return nil
        }
        let flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
            let code = Int(event.keyCode)
            if [54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(code) {
                keyCode = code
                stopRecording()
            }
            return nil
        }
        if let keyMonitor { eventMonitors.append(keyMonitor) }
        if let flagsMonitor { eventMonitors.append(flagsMonitor) }
    }

    private func stopRecording() {
        isRecording = false
        for monitor in eventMonitors { NSEvent.removeMonitor(monitor) }
        eventMonitors.removeAll()
    }

    private var presetKeys: [(name: String, code: Int)] {
        [("Right ⌥", 61), ("Left ⌥", 58), ("Right ⌃", 62), ("Left ⌃", 59), ("Fn", 63)]
    }

    private func keyName(for code: Int) -> String {
        switch code {
        case 61: return "⌥  Right Option"
        case 58: return "⌥  Left Option"
        case 59: return "⌃  Left Control"
        case 62: return "⌃  Right Control"
        case 63: return "Fn"
        case 56: return "⇧  Left Shift"
        case 60: return "⇧  Right Shift"
        case 55: return "⌘  Left Command"
        case 54: return "⌘  Right Command"
        case 57: return "⇪  Caps Lock"
        case 36: return "↩  Return"
        case 49: return "␣  Space"
        case 53: return "⎋  Escape"
        case 48: return "⇥  Tab"
        default:
            if let name = keyCodeToString(code) { return name }
            return "Key \(code)"
        }
    }

    private func keyCodeToString(_ code: Int) -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let layoutDataRef = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let layoutData = unsafeBitCast(layoutDataRef, to: CFData.self)
        let layout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length: Int = 0
        let status = UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0,
                                     UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysBit),
                                     &deadKeyState, chars.count, &length, &chars)
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}

// MARK: - Model Section

private struct ModelSection: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var modelManager: ModelManager
    let engine: DictationEngine
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 14) {
            // Recommended quantized models
            CardHeader("Recommended (Quantized)", subtitle: "Smaller, faster, near-identical accuracy")

            ForEach(ModelManager.ModelInfo.recommended) { model in
                modelCard(model)
            }

            // VAD model
            CardHeader("Voice Activity Detection", subtitle: "Trims silence for faster inference (2 MB)")

            let vadDownloaded = modelManager.isModelDownloaded(ModelManager.ModelInfo.vadSilero)
            SettingsCard(colorScheme: colorScheme) {
                HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [AppTheme.cyan.opacity(0.78), AppTheme.logoYellow.opacity(0.52)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                    Image(systemName: "waveform.path")
                        .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Silero VAD")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Auto-trims silence before transcription")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if vadDownloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 18))
                    } else if modelManager.isDownloading {
                        ProgressView(value: modelManager.downloadProgress)
                            .frame(width: 60)
                    } else {
                        Button("Download") {
                            Task { try? await modelManager.downloadModel(.vadSilero) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            // Full precision models (collapsible)
            DisclosureGroup {
                VStack(spacing: 10) {
                    ForEach([ModelManager.ModelInfo.baseEn, .smallEn, .mediumEn]) { model in
                        modelCard(model)
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("Full Precision Models")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let error = modelManager.downloadError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func modelCard(_ model: ModelManager.ModelInfo) -> some View {
        let isSelected = isModelSelected(model)
        let isDownloaded = modelManager.isModelDownloaded(model)

        SettingsCard(colorScheme: colorScheme) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(tierGradient(for: model))
                        .frame(width: 36, height: 36)
                    Text(tierEmoji(for: model))
                        .font(.system(size: 16))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(model.name)
                            .font(.system(size: 13, weight: .semibold))
                        if model.isQuantized {
                            Text("Q5")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.3)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(.orange.opacity(0.15)))
                                .foregroundStyle(.orange)
                        }
                        if isSelected {
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.5)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppTheme.readyGreen.opacity(0.16)))
                                .foregroundStyle(AppTheme.readyGreen)
                        }
                    }
                    HStack(spacing: 12) {
                        Label(model.size, systemImage: "internaldrive")
                        Label(model.speed, systemImage: "bolt.fill")
                        Label(model.accuracy, systemImage: "target")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if isDownloaded {
                    if !isSelected {
                        Button("Activate") {
                            let name = model.fileName
                                .replacingOccurrences(of: "ggml-", with: "")
                                .replacingOccurrences(of: ".bin", with: "")
                            settings.selectedModel = name
                            engine.reloadModel()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(AppTheme.logoYellow)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 18))
                    }
                } else if modelManager.isDownloading {
                    ProgressView(value: modelManager.downloadProgress)
                        .frame(width: 60)
                } else {
                    Button("Download") {
                        Task { try? await modelManager.downloadModel(model) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private func isModelSelected(_ model: ModelManager.ModelInfo) -> Bool {
        let modelKey = model.fileName
            .replacingOccurrences(of: "ggml-", with: "")
            .replacingOccurrences(of: ".bin", with: "")
        return settings.selectedModel == modelKey
    }

    private func tierGradient(for model: ModelManager.ModelInfo) -> LinearGradient {
        switch model.fileName {
        case let f where f.contains("base"): return LinearGradient(colors: [AppTheme.readyGreen.opacity(0.78), AppTheme.readyGreen.opacity(0.42)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case let f where f.contains("small"): return LinearGradient(colors: [AppTheme.cyan.opacity(0.78), AppTheme.cyan.opacity(0.42)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: return LinearGradient(colors: [AppTheme.logoYellow.opacity(0.86), Color(red: 0.92, green: 0.48, blue: 0.10).opacity(0.58)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func tierEmoji(for model: ModelManager.ModelInfo) -> String {
        switch model.fileName {
        case let f where f.contains("base"): return "⚡"
        case let f where f.contains("small"): return "🎯"
        default: return "🧠"
        }
    }

    private func tierSpeed(for model: ModelManager.ModelInfo) -> String {
        switch model.fileName {
        case let f where f.contains("base"): return "Fastest"
        case let f where f.contains("small"): return "Balanced"
        default: return "Most accurate"
        }
    }
}

// MARK: - History Section

private struct HistorySection: View {
    @ObservedObject var memory: DictationMemory
    let colorScheme: ColorScheme
    @State private var isActivityExpanded = false
    @State private var selectedActivityMonth = Date()
    @State private var availableWidth: CGFloat = 0

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: historyMetricColumns, spacing: 12) {
                ForEach(historyMetricCards) { card in
                    HistoryMetricCard(descriptor: card, colorScheme: colorScheme)
                }
            }

            SettingsCard(colorScheme: colorScheme) {
                HStack {
                    CardHeader("Learned Terms", subtitle: "Terms detected from your own speech")
                    Spacer()
                    if !memory.learnedTerms.isEmpty {
                        Button("Clear") { memory.clearLearnedTerms() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }

                if memory.learnedTerms.isEmpty {
                    EmptyStateLine(icon: "sparkles", text: "Dictate a few messages and learned terms will appear here.")
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(memory.learnedTerms.prefix(50)) { term in
                            LearnedTermPill(term: term, colorScheme: colorScheme) {
                                memory.promoteToCustomTerm(term.term)
                            } onDelete: {
                                memory.removeLearnedTerm(term.term)
                            }
                        }
                    }
                }
            }

            SettingsCard(colorScheme: colorScheme) {
                HStack(alignment: .center) {
                    CardHeader(
                        "Activity History",
                        subtitle: isActivityExpanded ? "Browse monthly dictation patterns" : "Current calendar week"
                    )
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            isActivityExpanded.toggle()
                        }
                    } label: {
                        Label(isActivityExpanded ? "Collapse" : "Expand", systemImage: isActivityExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if memory.history.isEmpty {
                    EmptyStateLine(icon: "chart.bar.xaxis", text: "Daily activity appears here once you have dictation history.")
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ActivitySummaryStrip(
                            title: isActivityExpanded ? monthTitle : "This week",
                            buckets: isActivityExpanded ? monthBuckets : currentWeekBuckets,
                            colorScheme: colorScheme
                        )

                        if isActivityExpanded {
                            MonthActivityControls(
                                selectedDate: $selectedActivityMonth,
                                colorScheme: colorScheme,
                                previous: { shiftActivityMonth(by: -1) },
                                next: { shiftActivityMonth(by: 1) }
                            )

                            MonthActivityGrid(
                                weeks: selectedMonthWeeks,
                                selectedMonth: selectedActivityMonth,
                                colorScheme: colorScheme
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            WeeklyWordBars(days: currentWeekBuckets, colorScheme: colorScheme)
                                .transition(.opacity)
                        }
                    }
                }
            }

            SettingsCard(colorScheme: colorScheme) {
                HStack {
                    CardHeader("Recent Dictations", subtitle: "Local transcript history")
                    Spacer()
                    if !memory.history.isEmpty {
                        Button("Clear") { memory.clearHistory() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }

                if memory.history.isEmpty {
                    EmptyStateLine(icon: "text.bubble", text: "Your successful dictations will be listed here.")
                } else {
                    VStack(spacing: 8) {
                        ForEach(memory.history.prefix(30)) { item in
                            HistoryRow(item: item, colorScheme: colorScheme)
                        }
                    }
                }
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        updateAvailableWidth(proxy.size.width)
                    }
                    .onChange(of: proxy.size.width) { _, width in
                        updateAvailableWidth(width)
                    }
            }
        )
    }

    private var historyMetricCards: [DashboardMetricDescriptor] {
        [
            DashboardMetricDescriptor(title: "Dictations", value: "\(memory.history.count)", trend: "stored locally", icon: "mic.badge.plus", color: AppTheme.logoYellow),
            DashboardMetricDescriptor(title: "Total Words", value: formatted(totalWords), trend: "all-time memory", icon: "text.word.spacing", color: AppTheme.readyGreen),
            DashboardMetricDescriptor(title: "Average WPM", value: "\(averageWPM)", trend: "speech speed", icon: "gauge.with.dots.needle.67percent", color: AppTheme.cyan),
            DashboardMetricDescriptor(title: "Learned Terms", value: "\(memory.learnedTerms.count)", trend: "vocabulary bias", icon: "sparkles", color: Color(red: 1.0, green: 0.66, blue: 0.12)),
            DashboardMetricDescriptor(title: "Cleanup Cuts", value: "\(cleanupCuts)", trend: "fillers removed", icon: "wand.and.stars", color: Color(red: 0.74, green: 0.48, blue: 1.0)),
            DashboardMetricDescriptor(title: "Time Saved", value: timeSavedLabel, trend: "vs typing", icon: "clock.badge.checkmark", color: Color(red: 0.95, green: 0.45, blue: 0.28))
        ]
    }

    private var historyMetricColumns: [GridItem] {
        let count: Int
        if availableWidth >= 960 {
            count = 6
        } else if availableWidth >= 520 {
            count = 3
        } else if availableWidth >= 420 {
            count = 2
        } else {
            count = 1
        }
        return Array(repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12), count: count)
    }

    private func updateAvailableWidth(_ width: CGFloat) {
        guard abs(width - availableWidth) > 1 else { return }
        availableWidth = width
    }

    private var totalWords: Int {
        memory.history.reduce(0) { $0 + $1.wordCount }
    }

    private var averageWPM: Int {
        let items = memory.history.filter { $0.audioDuration > 0.5 }
        let totalSeconds = items.reduce(0.0) { $0 + $1.audioDuration }
        guard totalWords > 0, totalSeconds > 0 else { return 0 }
        return Int((Double(totalWords) / totalSeconds * 60).rounded())
    }

    private var cleanupCuts: Int {
        memory.history.reduce(0) { $0 + ($1.cleanupCutCount ?? 0) }
    }

    private var timeSavedLabel: String {
        let minutes = max(0, Int((Double(totalWords) / 45.0).rounded()))
        if minutes >= 60 {
            return String(format: "%.1fh", Double(minutes) / 60.0)
        }
        return "\(minutes)m"
    }

    private func formatted(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private var currentWeekBuckets: [DailyWordBucket] {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? Date()
        return dailyBuckets(
            startingAt: weekStart,
            endingAt: weekEnd,
            calendar: calendar,
            history: memory.history
        )
    }

    private var selectedMonthWeeks: [[DailyWordBucket]] {
        monthWeekBuckets(containing: selectedActivityMonth, calendar: calendar, history: memory.history)
    }

    private var monthBuckets: [DailyWordBucket] {
        selectedMonthWeeks.flatMap { $0 }.filter { calendar.isDate($0.date, equalTo: selectedActivityMonth, toGranularity: .month) }
    }

    private var monthTitle: String {
        Self.monthFormatter.string(from: selectedActivityMonth)
    }

    private func shiftActivityMonth(by value: Int) {
        selectedActivityMonth = calendar.date(byAdding: .month, value: value, to: selectedActivityMonth) ?? selectedActivityMonth
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
}

private struct StatBlock: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EmptyStateLine: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct LearnedTermPill: View {
    let term: LearnedTerm
    let colorScheme: ColorScheme
    let onPromote: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Text(term.term)
                .font(.system(size: 11, weight: .medium))
            Text("\(term.count)")
                .font(.system(size: 9, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button(action: onPromote) {
                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .help("Add to manual vocabulary")
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .help("Remove learned term")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
        )
        .overlay(
            Capsule()
                .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08), lineWidth: 0.5)
        )
    }
}

private struct ActivitySummaryStrip: View {
    let title: String
    let buckets: [DailyWordBucket]
    let colorScheme: ColorScheme

    private var words: Int { buckets.reduce(0) { $0 + $1.words } }
    private var dictations: Int { buckets.reduce(0) { $0 + $1.dictations } }
    private var averageWPM: Int {
        let seconds = buckets.reduce(0.0) { $0 + $1.audioDuration }
        guard words > 0, seconds > 0 else { return 0 }
        return Int((Double(words) / seconds * 60).rounded())
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.brandGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(dictations) dictations")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Spacer()

            SummaryMetric(value: "\(words)", label: "words")
            SummaryMetric(value: "\(averageWPM)", label: "wpm")
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(colorScheme == .dark ? Color.black.opacity(0.18) : AppTheme.logoYellow.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(AppTheme.logoYellow.opacity(colorScheme == .dark ? 0.16 : 0.26), lineWidth: 0.7)
        )
    }
}

private struct SummaryMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .frame(width: 58, alignment: .trailing)
    }
}

private struct MonthActivityControls: View {
    @Binding var selectedDate: Date
    let colorScheme: ColorScheme
    let previous: () -> Void
    let next: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: previous) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.borderless)
            .help("Previous month")

            DatePicker("Month", selection: $selectedDate, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(width: 138)

            Button(action: next) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.borderless)
            .help("Next month")

            Spacer()

            Text("Each row is one calendar week")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 2)
    }
}

private struct MonthActivityGrid: View {
    let weeks: [[DailyWordBucket]]
    let selectedMonth: Date
    let colorScheme: ColorScheme

    private var calendar: Calendar { .current }
    private var maxWords: Int {
        max(weeks.flatMap { $0 }.map(\.words).max() ?? 0, 1)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 7) {
                    ForEach(week) { bucket in
                        ActivityDayCell(
                            bucket: bucket,
                            maxWords: maxWords,
                            isInSelectedMonth: calendar.isDate(bucket.date, equalTo: selectedMonth, toGranularity: .month),
                            colorScheme: colorScheme
                        )
                    }
                }
            }
        }
    }

    private static let weekdaySymbols: [String] = {
        let formatter = DateFormatter()
        return formatter.shortStandaloneWeekdaySymbols.map { String($0.prefix(2)).uppercased() }
    }()
}

private struct ActivityDayCell: View {
    let bucket: DailyWordBucket
    let maxWords: Int
    let isInSelectedMonth: Bool
    let colorScheme: ColorScheme
    @State private var isHovering = false

    private var fillRatio: CGFloat {
        guard maxWords > 0 else { return 0 }
        return min(1, CGFloat(bucket.words) / CGFloat(maxWords))
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text("\(Calendar.current.component(.day, from: bucket.date))")
                    .font(.system(size: 10, weight: isHovering ? .bold : .semibold))
                    .monospacedDigit()
                Spacer(minLength: 0)
                if bucket.dictations > 0 {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 5, height: 5)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.045))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(activityGradient)
                        .frame(height: max(bucket.words > 0 ? 5 : 0, proxy.size.height * fillRatio))
                }
            }
            .frame(height: 42)

            Text("\(bucket.words)")
                .font(.system(size: isHovering ? 12 : 10, weight: .bold, design: .rounded))
                .foregroundStyle(bucket.words > 0 ? AppTheme.logoYellowSoft : .secondary)
                .monospacedDigit()

            Text(isHovering ? "\(bucket.dictations) captures • \(bucket.averageWPM) wpm" : " ")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 112)
        .opacity(isInSelectedMonth ? 1 : 0.42)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color.white.opacity(isHovering ? 0.075 : 0.045) : Color.white.opacity(isHovering ? 0.84 : 0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(bucket.words > 0 ? dotColor.opacity(isHovering ? 0.56 : 0.34) : Color.clear, lineWidth: isHovering ? 1 : 0.7)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovering = hovering
            }
        }
        .help("\(bucket.words) words, \(bucket.dictations) dictations, \(bucket.averageWPM) wpm")
    }

    private var dotColor: Color {
        if bucket.averageWPM >= 140 { return AppTheme.cyan }
        if bucket.words >= maxWords && bucket.words > 0 { return AppTheme.readyGreen }
        return AppTheme.logoYellow
    }

    private var activityGradient: LinearGradient {
        LinearGradient(
            colors: [AppTheme.logoYellow, dotColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct HistoryRow: View {
    let item: DictationHistoryItem
    let colorScheme: ColorScheme
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(Self.formatter.string(from: item.timestamp))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(item.language)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(item.appName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(item.wordCount) words")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "Collapse dictation" : "Expand dictation")
            }
            SelectableHistoryText(
                text: item.text,
                isExpanded: isExpanded,
                colorScheme: colorScheme
            )
            .frame(height: isExpanded ? expandedTextHeight : 52)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(isExpanded ? 1 : 0)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color.black.opacity(0.18) : Color.black.opacity(0.035))
        )
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private var expandedTextHeight: CGFloat {
        let estimatedLines = item.text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .reduce(0) { total, line in
                total + max(1, Int(ceil(Double(line.count) / 96.0)))
            }
        return CGFloat(min(max(estimatedLines, 4), 90)) * 17 + 12
    }
}

private struct SelectableHistoryText: NSViewRepresentable {
    let text: String
    let isExpanded: Bool
    let colorScheme: ColorScheme

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.allowsUndo = false
        textView.usesFindBar = false
        textView.font = NSFont.systemFont(ofSize: 12)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.string = isExpanded ? text : truncatedText
        textView.textColor = colorScheme == .dark ? NSColor.labelColor : NSColor.labelColor
        textView.backgroundColor = .clear
        textView.font = NSFont.systemFont(ofSize: 12)
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
    }

    private var truncatedText: String {
        let limit = 320
        guard text.count > limit else { return text }
        return String(text.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}

// MARK: - Vocabulary Section

private struct VocabularySection: View {
    @ObservedObject var settings: AppSettings
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 14) {
            // Names & Terms
            SettingsCard(colorScheme: colorScheme) {
                CardHeader("Names & Terms", subtitle: "Add names of people, places, and terms you use often")
                CustomTermsEditor(settings: settings, colorScheme: colorScheme)
            }

            // Developer Vocabulary
            SettingsCard(colorScheme: colorScheme) {
                CardHeader("Developer Vocabulary", subtitle: "Bias Whisper toward recognizing these terms")
                TextEditor(text: $settings.vocabularyPrompt)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color(.textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08), lineWidth: 0.5)
                    )

                HStack {
                    Text("Add project-specific terms for better recognition")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button("Reset") {
                        settings.vocabularyPrompt = AppSettings.defaultVocabularyPrompt
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}

// MARK: - Custom Terms Editor

private struct CustomTermsEditor: View {
    @ObservedObject var settings: AppSettings
    let colorScheme: ColorScheme
    @State private var newTerm = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Input row
            HStack(spacing: 8) {
                TextField("Type a name or term...", text: $newTerm)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { addTerm() }

                Button("Add") { addTerm() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(AppTheme.logoYellow)
                    .disabled(newTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || settings.customTerms.count >= 100)
            }

            // Pills
            if !settings.customTerms.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(settings.customTerms, id: \.self) { term in
                        TermPill(term: term, colorScheme: colorScheme) {
                            settings.removeCustomTerm(term)
                        }
                    }
                }

                HStack {
                    let count = settings.customTerms.count
                    Text("\(count) / 100 terms")
                        .font(.system(size: 11))
                        .foregroundColor(count >= 100 ? .orange : .secondary.opacity(0.5))
                    Spacer()
                    Button("Clear All") {
                        settings.customTerms = []
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private func addTerm() {
        settings.addCustomTerm(newTerm)
        newTerm = ""
    }
}

// MARK: - Term Pill

private struct TermPill: View {
    let term: String
    let colorScheme: ColorScheme
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(term)
                .font(.system(size: 11, weight: .medium))
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
        )
        .overlay(
            Capsule()
                .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight + (i > 0 ? spacing : 0)
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            if i > 0 { y += spacing }
            var x = bounds.minX
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(subview)
            currentWidth += size.width + spacing
        }
        return rows
    }
}

// MARK: - Protocols Section

private struct ProtocolsSection: View {
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(colorScheme: colorScheme) {
                CardHeader("Core Stability Protocol", subtitle: "The functional path that must stay intact before any design or feature work ships")
                ProtocolChecklist(items: [
                    "Signing identity and bundle identifier must stay stable: Dictator-md Stable Local + com.dictatormd.DictatorMD.",
                    "Local builds must fail rather than fall back to ad-hoc signing; ad-hoc signatures break macOS Accessibility grants.",
                    "Install local builds only through make install-local so old DictatorMD/WhisperDictation app registrations are removed before launch.",
                    "Permission UI must reflect real runtime checks only: microphone uses AVCapture authorization; Accessibility uses AXIsProcessTrusted().",
                    "Hotkey capture must keep a working fallback: event tap when Accessibility is trusted, NSEvent fallback when it is not.",
                    "Recording must not start unless the local model is loaded and microphone access is authorized.",
                    "Insertion must preserve the target app captured at recording start and keep direct Unicode typing as the fallback.",
                    "Clipboard paste may be optimized, but it must never replace the direct typing fallback or silently discard the transcript.",
                    "After any change to hotkey, permissions, audio, transcription, focus tracking, or insertion, run a real dictation test into another app before handoff."
                ])
            }

            SettingsCard(colorScheme: colorScheme) {
                CardHeader("Self-Learning Protocol", subtitle: "How local personalization works and how future improvements should plug in")
                ProtocolChecklist(items: [
                    "Every successful dictation is stored locally in memory.json with text, language, target app, duration, timestamp, and word count.",
                    "The learner extracts probable personal terms: Bulgarian/Cyrillic words, names, acronym-shaped words, hyphenated terms, digits, and technical tokens.",
                    "Learned terms are counted and ranked by frequency and recency, then fed back into future Whisper prompts as local biasing context.",
                    "Manual vocabulary always remains user-controlled and higher confidence than automatically learned terms.",
                    "Language profiles must not poison each other: English prompt terms avoid Cyrillic; Bulgarian can use Cyrillic and repeated local terms.",
                    "The learner must stay offline and lightweight. It can process local text/statistics, but must not require cloud APIs.",
                    "Future learning features should be added here first as a protocol rule, then implemented, then verified against history and live dictation."
                ])
            }
        }
    }
}

private struct ProtocolChecklist: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 9) {
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 20, height: 20)
                        .background(AppTheme.logoYellow)
                        .clipShape(Circle())
                    Text(item)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Permissions Section

private struct PermissionsSection: View {
    @ObservedObject var permissions: PermissionManager
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 14) {
            PermissionCard(
                icon: "mic.fill",
                title: "Microphone",
                description: "Capture your voice for transcription",
                isGranted: permissions.microphoneGranted,
                colorScheme: colorScheme,
                action: { permissions.requestMicrophone() },
                actionLabel: "Grant Access"
            )

            PermissionCard(
                icon: "keyboard.badge.eye",
                title: "Accessibility",
                description: "Enabled in macOS Settings",
                isGranted: permissions.accessibilityGranted,
                colorScheme: colorScheme,
                action: { permissions.openAccessibilitySettings() },
                actionLabel: "Open Settings"
            )

            Button {
                permissions.checkPermissions()
            } label: {
                Label("Refresh Permissions", systemImage: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

private struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    let actionLabel: String

    var body: some View {
        SettingsCard(colorScheme: colorScheme) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isGranted
                            ? LinearGradient(colors: [.green.opacity(0.7), .green.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [.red.opacity(0.7), .red.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: isGranted ? "checkmark" : icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !isGranted {
                    Button(actionLabel, action: action)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(AppTheme.logoYellow)
                }
            }
        }
    }
}
