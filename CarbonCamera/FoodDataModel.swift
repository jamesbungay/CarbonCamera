//
//  FoodDataModel.swift
//  CarbonCamera
//
//  Created by James Bungay on 26/07/2020.
//  Copyright © 2020 James Bungay. All rights reserved.
//

import Foundation

class FoodDataModel {
    
    private var dataSet: [[String]]
    
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
            let columns = row.components(separatedBy: ",")
            csvAsArray.append(columns)
        }
        
        csvAsArray = Array(csvAsArray.dropFirst(1))  // Drop column names
        csvAsArray = Array(csvAsArray.dropLast(1))  // Drop empty final line of csv
        
        return csvAsArray
    }
    
    
    // MARK: Getters for dataset values
    
    func getFoodIDOf(classificationIdentifier: String) -> Int? {  // Returns nil if input classificationIdenfitier was not in food-info-datafile
        
        let classificationIdentifierCommaReplaced = classificationIdentifier.replacingOccurrences(of: ",", with: ";")
        
        for food in self.dataSet {
            if food[5] == classificationIdentifierCommaReplaced {
                guard let foodIDOut = Int(food[0])
                    else { return nil }
                return foodIDOut
            }
        }
        
        return nil
    }
    
    func getNameFromFoodID(foodID: Int) -> String? {
        
        for food in self.dataSet {
            if food[0] == String(foodID) {
                return food[1]
            }
        }
        
        return nil
    }
    
    func getPortionSizeTextFromFoodID(foodID: Int) -> String? {
        
        for food in self.dataSet {
            if food[0] == String(foodID) {
                return food[2]
            }
        }
        
        return nil
    }
    
    func getPortionSizeValueFromFoodID(foodID: Int) -> Double? {
        
        for food in self.dataSet {
            if food[0] == String(foodID) {
                guard let portionSizeValueOut = Double(food[3])
                    else { return nil }
                return portionSizeValueOut
            }
        }
        
        return nil
    }
    
    func getCO2eFromFoodID(foodID: Int) -> String? {
        
        for food in self.dataSet {
            if food[0] == String(foodID) {
                return food[4]
            }
        }
        
        return "0"
    }
    
}
