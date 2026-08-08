//
//  OurPlacesWidgetLiveActivity.swift
//  OurPlacesWidget
//
//  Created by SAIRAM  on 27/03/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct OurPlacesWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct OurPlacesWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OurPlacesWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension OurPlacesWidgetAttributes {
    fileprivate static var preview: OurPlacesWidgetAttributes {
        OurPlacesWidgetAttributes(name: "World")
    }
}

extension OurPlacesWidgetAttributes.ContentState {
    fileprivate static var smiley: OurPlacesWidgetAttributes.ContentState {
        OurPlacesWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: OurPlacesWidgetAttributes.ContentState {
         OurPlacesWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: OurPlacesWidgetAttributes.preview) {
   OurPlacesWidgetLiveActivity()
} contentStates: {
    OurPlacesWidgetAttributes.ContentState.smiley
    OurPlacesWidgetAttributes.ContentState.starEyes
}
