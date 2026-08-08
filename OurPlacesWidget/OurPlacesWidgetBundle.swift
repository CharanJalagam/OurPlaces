//
//  OurPlacesWidgetBundle.swift
//  OurPlacesWidget
//
//  Created by SAIRAM  on 27/03/26.
//

import WidgetKit
import SwiftUI

@main
struct OurPlacesWidgetBundle: WidgetBundle {
    var body: some Widget {
        OurPlacesWidget()
        OurPlacesWidgetControl()
        OurPlacesWidgetLiveActivity()
    }
}
