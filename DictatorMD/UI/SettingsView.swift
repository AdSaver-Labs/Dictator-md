import SwiftUI
import Carbon.HIToolbox

private enum AppTheme {
    static let logoYellow = Color(red: 1.0, green: 0.82, blue: 0.16)
    static let logoYellowSoft = Color(red: 1.0, green: 0.90, blue: 0.42)
    static let ink = Color(red: 0.09, green: 0.09, blue: 0.08)
    static let graphite = Color(red: 0.18, green: 0.18, blue: 0.17)
    static let readyGreen = Color(red: 0.24, green: 0.78, blue: 0.36)
    static let cyan = Color(red: 0.13, green: 0.76, blue: 0.82)

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [logoYellowSoft, logoYellow],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var selectedGradient: LinearGradient {
        LinearGradient(
            colors: [logoYellow, Color(red: 0.90, green: 0.58, blue: 0.08)],
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

        var icon: String {
            switch self {
            case .dashboard: "chart.bar.xaxis"
            case .general: "gearshape.fill"
            case .model: "brain.head.profile.fill"
            case .history: "clock.arrow.circlepath"
            case .vocabulary: "text.book.closed.fill"
            case .protocols: "list.bullet.clipboard.fill"
            case .permissions: "lock.shield.fill"
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
        .frame(minWidth: 920, idealWidth: 1040, minHeight: 660, idealHeight: 720)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                DictatorLogoMark(size: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dictator-md")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("Local voice input")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            ForEach(SettingsSection.allCases) { section in
                Button {
                    DebugLog.shared.log("[SettingsView] sidebar selected \(section.rawValue)")
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedSection = section
                    }
                } label: {
                    SidebarRow(
                        title: section.rawValue,
                        icon: section.icon,
                        isSelected: selectedSection == section,
                        colorScheme: colorScheme
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

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
        .frame(width: 188)
        .background(
            colorScheme == .dark
                ? Color.black.opacity(0.20)
                : Color.white.opacity(0.50)
        )
    }

    // MARK: - Detail Pane

    private var detailPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(selectedSection.rawValue)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text(sectionSubtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
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
                .padding(.bottom, 18)

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

    private var sectionSubtitle: String {
        switch selectedSection {
        case .dashboard: "Live stats, local memory, and dictation health."
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

// MARK: - Card

private struct SettingsCard<Content: View>: View {
    let colorScheme: ColorScheme
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color.white.opacity(0.065) : Color.white.opacity(0.72))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.05), radius: 12, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.72),
                    lineWidth: 0.7
                )
        )
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
                .font(.system(size: 13, weight: .semibold))
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

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                DashboardHeroCard(
                    statusTitle: statusTitle,
                    state: engine.state,
                    wordsToday: wordsToday,
                    averageWPM: averageWPMThisWeek,
                    colorScheme: colorScheme
                )

                VStack(spacing: 14) {
                    DashboardStatusPanel(
                        title: "Language Mode",
                        value: shortLanguageLabel,
                        subtitle: settings.dictationLanguage.label,
                        icon: "globe.europe.africa.fill",
                        tint: AppTheme.cyan,
                        colorScheme: colorScheme
                    )
                    DashboardStatusPanel(
                        title: "Local Engine",
                        value: engine.isModelLoaded ? "Ready" : "Loading",
                        subtitle: settings.selectedModel,
                        icon: "brain.head.profile.fill",
                        tint: engine.isModelLoaded ? AppTheme.readyGreen : .orange,
                        colorScheme: colorScheme
                    )
                    DashboardFloatingNodeCard(language: settings.dictationLanguage, colorScheme: colorScheme)
                }
                .frame(width: 250)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                DashboardMetricCard(title: "Today's Words", value: "\(wordsToday)", subtitle: "dictated today", icon: "quote.bubble.fill", color: AppTheme.logoYellow, colorScheme: colorScheme)
                DashboardMetricCard(title: "Weekly Words", value: "\(wordsThisWeek)", subtitle: "current calendar week", icon: "calendar", color: AppTheme.cyan, colorScheme: colorScheme)
                DashboardMetricCard(title: "Average WPM", value: "\(averageWPMThisWeek)", subtitle: "speech speed", icon: "speedometer", color: Color(red: 0.95, green: 0.46, blue: 0.14), colorScheme: colorScheme)
                DashboardMetricCard(title: "New Vocabulary", value: "\(newTermsThisWeek)", subtitle: "\(newTermsToday) today", icon: "sparkles", color: AppTheme.readyGreen, colorScheme: colorScheme)
            }

            SettingsCard(colorScheme: colorScheme) {
                HStack(alignment: .center) {
                    CardHeader("Weekly Activity", subtitle: "Current calendar week")
                    Spacer()
                    Text("\(weeklyDictations) dictations")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                WeeklyWordBars(days: weeklyBuckets, colorScheme: colorScheme)
            }

            HStack(alignment: .top, spacing: 14) {
                SettingsCard(colorScheme: colorScheme) {
                    CardHeader("Recent Dictations", subtitle: "Last local captures")
                    if memory.history.isEmpty {
                        EmptyStateLine(icon: "text.bubble", text: "Your recent dictations will show here.")
                    } else {
                        VStack(spacing: 8) {
                            ForEach(memory.history.prefix(4)) { item in
                                CompactHistoryRow(item: item, colorScheme: colorScheme)
                            }
                        }
                    }
                }

                SettingsCard(colorScheme: colorScheme) {
                    CardHeader("Self-Learning Vocabulary", subtitle: "Terms adapted from your usage")
                    if recentLearnedTerms.isEmpty {
                        EmptyStateLine(icon: "sparkles", text: "New project terms will appear here as you dictate.")
                    } else {
                        VStack(spacing: 8) {
                            ForEach(recentLearnedTerms) { term in
                                DashboardTermRow(term: term)
                            }
                        }
                    }
                }
            }
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
        return dailyBuckets(startingAt: weekStart, endingAt: Date(), calendar: calendar, history: memory.history)
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

    private var maxWords: Int {
        max(days.map(\.words).max() ?? 0, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    Text("\(day.words)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    GeometryReader { proxy in
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 5)
                                .fill(AppTheme.selectedGradient)
                                .frame(height: max(8, proxy.size.height * CGFloat(day.words) / CGFloat(maxWords)))
                        }
                    }
                    .frame(height: 86)
                    Text(Self.dayFormatter.string(from: day.date))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 2)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
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

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(colorScheme: colorScheme) {
                CardHeader("Self-Learning", subtitle: "Local memory built from your successful dictations")
                HStack(spacing: 14) {
                    StatBlock(value: "\(memory.history.count)", label: "dictations")
                    StatBlock(value: "\(totalWords)", label: "words")
                    StatBlock(value: "\(averageWPM)", label: "avg wpm")
                    StatBlock(value: "\(memory.learnedTerms.count)", label: "learned terms")
                }

                Text("The app uses repeated learned terms to bias future transcription prompts. Everything stays on this Mac.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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

    private var currentWeekBuckets: [DailyWordBucket] {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
        return dailyBuckets(
            startingAt: weekStart,
            endingAt: Date(),
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

    private var fillRatio: CGFloat {
        guard maxWords > 0 else { return 0 }
        return min(1, CGFloat(bucket.words) / CGFloat(maxWords))
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text("\(Calendar.current.component(.day, from: bucket.date))")
                    .font(.system(size: 10, weight: .semibold))
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
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(7)
        .frame(maxWidth: .infinity, minHeight: 82)
        .opacity(isInSelectedMonth ? 1 : 0.42)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color.white.opacity(0.045) : Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(bucket.words > 0 ? dotColor.opacity(0.34) : Color.clear, lineWidth: 0.7)
        )
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
            Text(item.text)
                .font(.system(size: 12))
                .lineLimit(isExpanded ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
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
