// The streak on the iPhone home screen — the WidgetKit side of
// lib/data/streak_widget.dart. Not part of the Xcode project yet: adding the
// extension target takes a few clicks in Xcode and an App Group on the
// developer account. See docs/home-screen-widget.md.
//
// Everything shown here was decided and translated by the app. It leaves a
// two-week timetable in the shared App Group; this widget only picks the row
// for the moment it is drawn, so it stays right at midnight and at eight in
// the evening without the app running.

import SwiftUI
import WidgetKit

private let appGroup = "group.com.hundreddays.hundredDays"
private let outlookKey = "streak_outlook"
private let lateHour = 20

struct OutlookDay: Decodable {
    let day: String
    let state: String
    let streak: Int
    let week: [String]
    let streakLabel: String
    let status: String
    let image: String
    let line: String
    let lateImage: String?
    let lateLine: String?
}

struct OutlookFallback: Decodable {
    let status: String
    let streakLabel: String
    let line: String
    let image: String
}

struct Outlook: Decodable {
    let goesOutIn: String
    let weekdays: [String]
    let fallback: OutlookFallback
    let days: [OutlookDay]
}

struct StreakEntry: TimelineEntry {
    let date: Date
    let outlook: Outlook?
    let day: OutlookDay?

    var state: String { day?.state ?? "cold" }

    var isLate: Bool {
        state == "open" && Calendar.current.component(.hour, from: date) >= lateHour
    }

    var imageKey: String? {
        guard let outlook else { return nil }
        guard let day else { return outlook.fallback.image }
        return isLate ? (day.lateImage ?? day.image) : day.image
    }

    var line: String {
        guard let outlook else { return "" }
        guard let day else { return outlook.fallback.line }
        return isLate ? (day.lateLine ?? day.line) : day.line
    }
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), outlook: nil, day: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        // Now, then every eight in the evening and every midnight the
        // timetable covers. The app asks for a reload whenever it changes.
        let calendar = Calendar.current
        let now = Date()
        var entries = [entry(at: now)]
        var day = calendar.startOfDay(for: now)
        for _ in 0..<14 {
            if let evening = calendar.date(byAdding: .hour, value: lateHour, to: day), evening > now {
                entries.append(entry(at: evening))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            entries.append(entry(at: next))
            day = next
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> StreakEntry {
        guard
            let json = UserDefaults(suiteName: appGroup)?.string(forKey: outlookKey),
            let data = json.data(using: .utf8),
            let outlook = try? JSONDecoder().decode(Outlook.self, from: data)
        else {
            return StreakEntry(date: date, outlook: nil, day: nil)
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        return StreakEntry(
            date: date,
            outlook: outlook,
            day: outlook.days.first { $0.day == key }
        )
    }
}

private extension Color {
    static let ink = Color(red: 5 / 255, green: 6 / 255, blue: 11 / 255)
    static let plasma = Color(red: 192 / 255, green: 132 / 255, blue: 252 / 255)
    static let hot = Color(red: 255 / 255, green: 77 / 255, blue: 109 / 255)
    static let attention = Color(red: 255 / 255, green: 126 / 255, blue: 182 / 255)
    static let sky = Color(red: 191 / 255, green: 219 / 255, blue: 254 / 255)
    static let violet = Color(red: 167 / 255, green: 139 / 255, blue: 250 / 255)
    static let success = Color(red: 63 / 255, green: 224 / 255, blue: 176 / 255)
    static let cool = Color(red: 138 / 255, green: 220 / 255, blue: 255 / 255)
    static let danger = Color(red: 255 / 255, green: 90 / 255, blue: 95 / 255)
    static let muted = Color(red: 164 / 255, green: 169 / 255, blue: 188 / 255)
    static let quiet = Color(red: 108 / 255, green: 113 / 255, blue: 134 / 255)
}

struct StreakWidgetView: View {
    let entry: StreakEntry
    @Environment(\.widgetFamily) private var family

    private var accent: Color {
        if entry.isLate { return .danger }
        switch entry.state {
        case "done": return .success
        case "open": return .attention
        case "rest", "frozen": return .cool
        default: return .muted
        }
    }

    private var tint: Color {
        if entry.isLate { return Color(red: 74 / 255, green: 16 / 255, blue: 36 / 255) }
        switch entry.state {
        case "done": return Color(red: 59 / 255, green: 31 / 255, blue: 122 / 255)
        case "open": return Color(red: 58 / 255, green: 23 / 255, blue: 88 / 255)
        case "rest", "frozen": return Color(red: 16 / 255, green: 42 / 255, blue: 74 / 255)
        default: return Color(red: 27 / 255, green: 30 / 255, blue: 42 / 255)
        }
    }

    private var flame: UIImage? {
        guard
            let key = entry.imageKey,
            let path = UserDefaults(suiteName: appGroup)?.string(forKey: key)
        else { return nil }
        return UIImage(contentsOfFile: path)
    }

    private var midnight: Date {
        Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: entry.date) ?? entry.date
        )
    }

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let flame {
                    Image(uiImage: flame)
                        .resizable()
                        .scaledToFit()
                        .frame(width: family == .systemSmall ? 52 : 80,
                               height: family == .systemSmall ? 52 : 80)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(entry.day?.streak ?? 0)")
                            .font(.system(size: family == .systemSmall ? 30 : 40,
                                          weight: .black, design: .rounded))
                            .foregroundStyle(LinearGradient(
                                colors: [.sky, .violet, .attention, .hot],
                                startPoint: .top, endPoint: .bottom))
                        Text((entry.day?.streakLabel ?? entry.outlook?.fallback.streakLabel ?? "")
                            .uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.muted)
                            .lineLimit(1)
                    }
                    Text(entry.day?.status ?? entry.outlook?.fallback.status
                        ?? String(localized: "widget.openApp"))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(accent)
                        .lineLimit(1)
                    if entry.state == "open", let outlook = entry.outlook {
                        HStack(spacing: 4) {
                            Text(outlook.goesOutIn)
                            // Counts down live, to the midnight that ends the streak.
                            Text(midnight, style: .timer)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(accent)
                                .monospacedDigit()
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.muted)
                    }
                    if family == .systemMedium {
                        Text(entry.line)
                            .font(.system(size: 12).italic())
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }
                }
            }
            if family == .systemMedium, let outlook = entry.outlook {
                WeekRow(letters: outlook.weekdays, marks: entry.day?.week ?? [])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

        let background = LinearGradient(
            colors: [tint, Color(red: 16 / 255, green: 18 / 255, blue: 26 / 255), .ink],
            startPoint: .topLeading, endPoint: .bottomTrailing)

        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(for: .widget) { background }
        } else {
            content.padding().background(background)
        }
    }
}

private struct WeekRow: View {
    let letters: [String]
    let marks: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                VStack(spacing: 1) {
                    Text(i < letters.count ? letters[i] : "")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.quiet)
                    glyph(i < marks.count ? marks[i] : "upcoming")
                        .font(.system(size: 13))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func glyph(_ mark: String) -> some View {
        switch mark {
        case "done": return Text("◆").foregroundColor(.plasma)
        case "frozen": return Text("❄").foregroundColor(.cool)
        case "missed": return Text("✕").foregroundColor(.danger)
        case "rest": return Text("☾").foregroundColor(.quiet)
        case "open": return Text("◇").foregroundColor(.attention)
        case "none": return Text(" ").foregroundColor(.quiet)
        default: return Text("·").foregroundColor(.quiet)
        }
    }
}

struct StreakWidget: Widget {
    let kind = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName(String(localized: "widget.label"))
        .description(String(localized: "widget.description"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct StreakWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
    }
}
