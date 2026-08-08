import WidgetKit
import SwiftUI

// MARK: - Entry

struct MyWidgetEntry: TimelineEntry {
    let date: Date
    let isLoggedIn: Bool
    let imagePath: String?
}

// MARK: - Provider

struct Provider: AppIntentTimelineProvider {
    
    func placeholder(in context: Context) -> MyWidgetEntry {
        MyWidgetEntry(date: Date(), isLoggedIn: false, imagePath: nil)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> MyWidgetEntry {
        MyWidgetEntry(date: Date(), isLoggedIn: false, imagePath: nil)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<MyWidgetEntry> {
        
        let manager = WidgetDataManager.shared
        
        let isLoggedIn = manager.getLoginState()
        let imagePath = manager.getLastImagePath()
        
        let entry = MyWidgetEntry(
            date: Date(),
            isLoggedIn: isLoggedIn,
            imagePath: imagePath
        )
        
        return Timeline(
            entries: [entry],
            policy: .after(Date().addingTimeInterval(60 * 15))
        )
    }
}

// MARK: - Widget View

struct OurPlacesWidgetEntryView: View {
    
    var entry: MyWidgetEntry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        default:
            smallView
        }
    }
}

// MARK: - Views

extension OurPlacesWidgetEntryView {
    
    // SMALL
    private var smallView: some View {
        ZStack {
            imageView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MEDIUM
    private var mediumView: some View {
        ZStack(alignment: .bottomLeading) {
            imageView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
//            LinearGradient(
//                colors: [.black.opacity(0.6), .clear],
//                startPoint: .bottom,
//                endPoint: .top
//            )
            
            Text(entry.isLoggedIn ? "Your Last Place 📍" : "Explore Places 🌍")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
        }
    }
    
    // LARGE
    private var largeView: some View {
        VStack(spacing: 0) {
            
            imageView
                .frame(maxHeight: .infinity)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.isLoggedIn ? "Recent Memory" : "Welcome to OurPlaces")
                        .font(.headline)
                    
                    Text(entry.isLoggedIn ? "Your latest saved photo" : "Save places & memories")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // IMAGE VIEW (Reusable)
    private var imageView: some View {
        GeometryReader { geo in
            Group {
                if entry.isLoggedIn,
                   let path = entry.imagePath,
                   FileManager.default.fileExists(atPath: path),
                   let uiImage = UIImage(contentsOfFile: path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.red
//                    Image("default_image")
//                        .resizable()
//                        .scaledToFill()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height) // 👈 explicit size from geometry
            .clipped()
        }
    }
}

// MARK: - Widget

struct OurPlacesWidget: Widget {
    
    let kind: String = "OurPlacesWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: Provider()
        ) { entry in
            OurPlacesWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { // 👈 Change this
                    Color.clear
                }
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    OurPlacesWidget()
} timeline: {
    MyWidgetEntry(date: .now, isLoggedIn: false, imagePath: nil)
}

#Preview(as: .systemMedium) {
    OurPlacesWidget()
} timeline: {
    MyWidgetEntry(date: .now, isLoggedIn: true, imagePath: nil)
}

#Preview(as: .systemLarge) {
    OurPlacesWidget()
} timeline: {
    MyWidgetEntry(date: .now, isLoggedIn: true, imagePath: nil)
}
