//
//  FoodDataModel.swift
//  CarbonCamera
//
//  Created by James Bungay on 26/07/2020.
//  Copyright © 2020 James Bungay. All rights reserved.
//

import Foundation

class FoodDataModel {
    
    // MARK: Food Dataset Interaction Methods
    
    func getFoodIDOf(classificationIdentifier: String) -> Int {  // Returns -1 if input classificationIdenfitier was not in food-info-datafile
        
        // TODO: Retrieve FoodID of input identifier
        return -1
    }
    
    func getCO2eFromFoodID(foodID: Int) -> String {
        return "0"
    }
    
    func getWaterUseFromFoodID(foodID: Int) -> String {
        return "0"
    }
    
}
