//
//  Tips.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-03-01.
//

import Foundation
import TipKit
import SwiftUI


struct NewRoomTip: Tip {
    var title: Text {
        Text("Create Area")
    }
    
    var message: Text? {
        Text("Click here to start adding an area.")
    }
    
  
}



struct WorldViewTip: Tip {
    var title: Text {
        Text("Saved Areas")
    }
    
    var message: Text? {
        Text("You can open the area map with \(Image(systemName: "arkit")); click for collaboration or view and find items.")
    }
    
    var image: Image? {
        Image(systemName: "arkit")
    }
  
}


struct ShareWorldsTip: Tip {
    var title: Text {
        Text("Saved iCloud Links")
    }
    
    var message: Text? {
        Text("You can open previously opened iCloud links from this drawer.")
    }
    
    var image: Image? {
        Image(systemName: "link.icloud.fill")
    }
  
}


struct StartCollaborationTip: Tip {
    var title: Text {
        Text("Collaborate with others")
    }
    
    var message: Text? {
        Text("You can make this area available for others to join collaboration from this menu.")
    }
    
    var image: Image? {
        Image(systemName: "person.2")
    }
  
}


struct FindItemTip: Tip {
    var title: Text {
        Text("Search Item in AR")
    }
    
    var message: Text? {
        Text("Tap on the item you are looking for and AR will highlight it and an arrow will guide you to it.")
    }
    
    var image: Image? {
        Image(systemName: "location.fill.viewfinder")
    }
  
}



