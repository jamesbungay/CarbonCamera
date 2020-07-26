//
//  UIScrollViewWithButtons.swift
//  CarbonCamera
//
//  Created by James Bungay on 26/07/2020.
//  Copyright © 2020 James Bungay. All rights reserved.
//

import UIKit

class UIScrollViewWithButtons: UIScrollView {

    // Swipes that occur on buttons or labels within the UIScrollView will not be consumed by the button or label, they will be recognised by the UIScrollView instead:
    
    override func touchesShouldCancel(in view: UIView) -> Bool {
        
        if view is UIButton || view is UILabel{
            return true
        }
        
        return touchesShouldCancel(in: view)
    }

}
