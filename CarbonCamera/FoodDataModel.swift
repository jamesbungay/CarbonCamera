//
//  FoodDataModel.swift
//  CarbonCamera
//
//  Created by James Bungay on 26/07/2020.
//  Copyright © 2020 James Bungay. All rights reserved.
//

import Foundation

class FoodDataModel {
    
    var dataSet: [[String]]  // TODO: make private
    
    init(resourceNameOfCsvToUse: String) {
        self.dataSet = FoodDataModel.loadCsvToArray(resourceName: resourceNameOfCsvToUse) ?? []
    }
    
    
    // MARK: func Load CSV file to array
    
    // Class method, not instance method, as used in instance initialisation:
    class func loadCsvToArray(resourceName: String) -> [[String]]? {
        
        // Read data from csv to string:
        
        guard let filePath = Bundle.main.path(forResource: resourceName, ofType: ".csv")
            else { return nil }
        
        var csvContents = ""
        do {
            csvContents = try String(contentsOf: URL(fileURLWithPath: filePath), encoding: .utf8)
        } catch { return nil }
        
        // Correct possible discrepencies in file formatting due to differences in Windows, Unix and Mac encoding of line separator characters:
        // See https://stackoverflow.com/questions/1279779/what-is-the-difference-between-r-and-n
        
        csvContents = csvContents.replacingOccurrences(of: "\r", with: "\n")
        csvContents = csvContents.replacingOccurrences(of: "\n\n", with: "\n")
        
        // Parse data from csv into respective rows and columns:
        
        var csvAsArray: [[String]] = []
        let rows = csvContents.components(separatedBy: "\n")
        for row in rows {
            let columns = row.components(separatedBy: ";")
            csvAsArray.append(columns)
        }
        
        csvAsArray = Array(csvAsArray.dropFirst(1))
        
        return csvAsArray
    }
    
    
    // MARK: Getters
    
    func getFoodIDOf(classificationIdentifier: String) -> Int {  // Returns -1 if input classificationIdenfitier was not in food-info-datafile
        
        // TODO: Retrieve FoodID of input identifier
        return -1
    }
    
    func getNameFromFoodID(foodID: Int) -> String {
        return "placeholderfoodname"
    }
    
    func getPortionSizeFromFoodID(foodID: Int) -> String {
        return "placeholderportionsize"
    }
    
    func getCO2eFromFoodID(foodID: Int) -> String {
        return "0"
    }
    
    func getWaterUseFromFoodID(foodID: Int) -> String {
        return "0"
    }
    
}
