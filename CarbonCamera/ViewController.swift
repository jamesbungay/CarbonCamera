//
//  ViewController.swift
//  CarbonCamera
//
//  Created by James Bungay on 22/07/2020.
//  Copyright © 2020 James Bungay. All rights reserved.
//

import UIKit
import AVFoundation
import Vision  // Vision module of CoreML


// TODO: Remove classification output from top of screen

// TODO: DONE - Show first classified food as suggestion button 0
// TODO: DONE - ...with highlighted edge to indicate that it is the current show food

// TODO: Maybe change green button colour to green shadow instead

// TODO: Spinning loading symbol on shutter button between clicking and classification complete

// TODO: Improve food info view ui arrangement

// TODO: Only have torch on when taking photo
// TODO: Reset torch button image when app comes back into view after being suspended

// TODO: DONE - Scroll suggestion buttons back to left when closing

// TODO: Replace shutter button with 'calorie mama' like button


class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var cameraPreviewView: CameraPreviewView!
    
    @IBOutlet weak var foodListButton: UIButton!
    @IBOutlet weak var torchButton: UIButton!
    @IBOutlet weak var shutterButton: UIButton!
    @IBOutlet weak var infoPanelCloseButton: UIButton!
    
    @IBOutlet weak var foodInfoTitleLabel: UILabel!
    @IBOutlet weak var foodInfoCO2ePerKgLabel: UILabel!
    @IBOutlet weak var foodInfoCO2ePerPortionLabel: UILabel!
    @IBOutlet weak var foodInfoCO2ePerPortionDescLabel: UILabel!
    
    @IBOutlet weak var foodInfoView: UIView!
    
    @IBOutlet weak var scrollViewForSuggestionButtons: UIScrollView!
    
    @IBOutlet var suggestionButtons: [FoodButton]!
    
    @IBOutlet weak var classificationResultLabel: UILabel!
    
    @IBOutlet weak var infoPanelStackViewBottomConstraint: NSLayoutConstraint!
    
    
    // Colours which are used throughout the UI:
    
    let colourHighlightBg = UIColor(red: 139/255, green: 206/255, blue: 123/255, alpha: 1)
    let colourBg = UIColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)
    let colourHighlightText = UIColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)
    let colourText = UIColor(red: 76/255, green: 84/255, blue: 100/255, alpha: 1)
    
    
    // Other variables in scope of whole class:
    
    let foodDataModel = FoodDataModel(resourceNameOfCsvToUse: "foodCarbonDataSet")
    
    var deviceHasTorch: Bool = false
    
    let captureSession = AVCaptureSession()
    
    var infoPanelVisible = true
    
    var videoFrameNeedsToBeProcessed = false  // Toggled true when shutter button pressed
    var readyToCaptureAndProcessImage = true  // Toggled true when no image is currently being pressed and info panel is not visible
    
    var currentFoodInfoShown: Int = -1  // Keeps track of which food suggestion is shown, out of the 6 foods whose buttons can be clicked to see their CO2e info when a photo is taken
    
    var suggestionButtonsCount: Int = -1  // Number of food suggestion buttons to be displayed below the food info view
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set info panel to initially be off screen, before a photo has been taken:
        
        self.infoPanelStackViewBottomConstraint.constant = -400
        self.view.layoutIfNeeded()
        
        // Verify authorisation for video capture, and then set up captureSession:
        
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized || AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            self.setUpCaptureSession()
        }
        
        // Initialise suggestion buttons with an identifying number and draw shadow around each one:
        
        suggestionButtonsCount = suggestionButtons.count
        for i in 0...(suggestionButtonsCount - 1) {
            
            suggestionButtons[i].suggestionButtonID = i
            
            suggestionButtons[i].layer.shadowPath = UIBezierPath(roundedRect: suggestionButtons[i].bounds, cornerRadius: suggestionButtons[i].layer.cornerRadius).cgPath
            suggestionButtons[i].layer.shadowRadius = 2
            suggestionButtons[i].layer.shadowOffset = .zero
            suggestionButtons[i].layer.shadowColor = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
            suggestionButtons[i].layer.shadowOpacity = 0.6
        }
        
        // Draw shadow around food info panel and other UI buttons:
        
        foodInfoView.layer.shadowPath = UIBezierPath(rect: foodInfoView.bounds).cgPath
        foodInfoView.layer.shadowRadius = 3
        foodInfoView.layer.shadowOffset = .zero
        foodInfoView.layer.shadowColor = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        foodInfoView.layer.shadowOpacity = 0.6
        
        infoPanelCloseButton.layer.shadowPath = UIBezierPath(roundedRect: infoPanelCloseButton.bounds, cornerRadius: infoPanelCloseButton.layer.cornerRadius).cgPath
        infoPanelCloseButton.layer.shadowRadius = 3
        infoPanelCloseButton.layer.shadowOffset = .zero
        infoPanelCloseButton.layer.shadowColor = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        infoPanelCloseButton.layer.shadowOpacity = 0.6
        
        torchButton.layer.shadowPath = UIBezierPath(roundedRect: torchButton.bounds, cornerRadius: torchButton.layer.cornerRadius).cgPath
        torchButton.layer.shadowRadius = 3
        torchButton.layer.shadowOffset = .zero
        torchButton.layer.shadowColor = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        torchButton.layer.shadowOpacity = 0.6
        
        foodListButton.layer.shadowPath = UIBezierPath(roundedRect: foodListButton.bounds, cornerRadius: foodListButton.layer.cornerRadius).cgPath
        foodListButton.layer.shadowRadius = 3
        foodListButton.layer.shadowOffset = .zero
        foodListButton.layer.shadowColor = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        foodListButton.layer.shadowOpacity = 0.6
        
        shutterButton.layer.shadowPath = UIBezierPath(roundedRect: shutterButton.bounds, cornerRadius: shutterButton.layer.cornerRadius).cgPath
        shutterButton.layer.shadowRadius = 3
        shutterButton.layer.shadowOffset = .zero
        shutterButton.layer.shadowColor = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        shutterButton.layer.shadowOpacity = 0.6
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        // If unauthorised for video capture, display an alert explaining why:
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .denied: // The user has previously denied access.
                showAlert(titleIn: "No camera access", msgIn: "Please allow camera access in settings for CarbonCamera to use this app.")
                return
            case .restricted: // The user can't grant access due to restrictions.
                showAlert(titleIn: "No camera access", msgIn: "Your parental restrictions prevent you from using the camera. Camera access is needed to use this app.")
                return
            default:
                return
        }
    }
    
    
    // MARK: captureSession Setup
    
    func setUpCaptureSession() {
        
        // Setup camera input to captureSession:
        
        captureSession.beginConfiguration()
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            else { return }  // Configuration failed, no back camera.
        
        self.deviceHasTorch = videoDevice.hasTorch
        
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice)
            else { return }  // Configuration failed, cannot use back camera as capture input device.
        
        if captureSession.canAddInput(videoDeviceInput) {
            captureSession.addInput(videoDeviceInput)
        } else { return }  // Configuration failed, cannot add input to captureSession.
        
        
        // Setup continuous video output from captureSession:
        
        let videoDataOutput = AVCaptureVideoDataOutput()  // Continuous video data output
        
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        } else { return }
        
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "queue.serial.videoQueue"))
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        } else { return }
        
        
        // Setup preview for captureSession:
        
        cameraPreviewView.videoPreviewLayer.session = captureSession
        cameraPreviewView.videoPreviewLayer.videoGravity = .resizeAspectFill  // Set video preview to fill the view
        
        captureSession.commitConfiguration()
        let serialQueue = DispatchQueue(label: "queue.serial.startCaptureSession")
        serialQueue.async {
            self.captureSession.startRunning()
        }
    }
    
    
    // MARK: Torch Toggle Method
    
    func toggleTorch() {
        guard let videoDevice = AVCaptureDevice.default(for: .video)
            else { return }
        
        guard videoDevice.hasTorch, videoDevice.isTorchAvailable
            else { return }
        
        if videoDevice.torchMode != .on {  // Turn on torch and configure button to show this:
            do {
                try videoDevice.lockForConfiguration()
                videoDevice.torchMode = .on
                torchButton.setImage(UIImage(systemName: "lightbulb"), for: UIControl.State.normal)
            } catch { return }  // Video device could not be reconfigured to turn on torch.
            
        } else {  // Turn off torch and configure button to show this:
            do {
                try videoDevice.lockForConfiguration()
                videoDevice.torchMode = .off
                torchButton.setImage(UIImage(systemName: "lightbulb.slash"), for: UIControl.State.normal)
            } catch { return }  // Video device could not be reconfigured to turn off torch.
        }
        
        videoDevice.unlockForConfiguration()  // Allow other apps to reconfigure video device.

    }
    
    
    // MARK: CaptureSession Continous-Video-Output Delegate Method
    
    // Function called every time the camera captures a frame:
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if !videoFrameNeedsToBeProcessed { return }
        videoFrameNeedsToBeProcessed = false  // A frame of video is now being handled in response to the shutter button being pressed, so no longer need to process another hense this boolean is set
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            else { return }
        
        classifyImageAndPassResultsToHandler(imageBufferIn: imageBuffer)
    }
    
    
    // MARK: Image Classification and Result Handling
    
    func classifyImageAndPassResultsToHandler(imageBufferIn: CVImageBuffer) {
        
        // Set up CoreML vision model, request and handler method:
        
        guard let visionModel = try? VNCoreMLModel(for: Resnet50().model)
            else { return }
        
        let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: {
            completedClassificationRequest, err in

            guard let results = completedClassificationRequest.results as? [VNClassificationObservation]
                else { return }
            
            self.handleResultsOfClassification(results: results)
            
            // Display result of classification in UI for testing purposes; do work on main thread:
            
//            DispatchQueue.main.async {
//                self.classificationResultLabel.text = String(results[0].identifier + " -- " + String(results[0].confidence))
//                self.classificationResultLabel.text! += String("\n" + results[1].identifier + " -- " + String(results[1].confidence))
//            }
        })
        
        let bgQueue = DispatchQueue(label: "queue.serial.classificationRequestHandler")
        bgQueue.async {
            let requestHandler = VNImageRequestHandler(cvPixelBuffer: imageBufferIn, options: [:])
            try? requestHandler.perform([classificationRequest])
        }
    }
    
    
    func handleResultsOfClassification(results: [VNClassificationObservation]) {
        
        // Get foodIDs of top n (default 6) classification results that are foods, still working off main queue/thread to prevent the UI from hanging:
        
        var topFoodIDs: [Int] = []
        var foodIDsLeftToObtain = suggestionButtonsCount
        var count = 0
        while foodIDsLeftToObtain > 0 {
            guard let returnedFoodID = foodDataModel.getFoodIDOf(classificationIdentifier: results[count].identifier)
                else { count += 1; continue }
            topFoodIDs.append(returnedFoodID)
            foodIDsLeftToObtain -= 1
            count += 1
        }
        
        // Make UI changes on main thread to display results such as C02e and suggested foods:
        
        DispatchQueue.main.async {
            
            self.setUpFoodInfoView(foodID: topFoodIDs[0])
            self.setUpFoodSuggestionsView(foodID: topFoodIDs)
            
            // Display info panel on screen:
            UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseInOut], animations: { self.infoPanelStackViewBottomConstraint.constant = 10; self.shutterButton.alpha = 0; self.torchButton.alpha = 0; self.foodListButton.alpha = 0; self.view.layoutIfNeeded() }, completion: nil)
            self.infoPanelVisible = true
        }
    }
    
    
    // MARK: Info View Config Methods
    
    func setUpFoodInfoView(foodID: Int) {
        
        let title = foodDataModel.getNameFromFoodID(foodID: foodID) ?? "Unknown Food"
        let co2ePerKg = foodDataModel.getCO2eFromFoodID(foodID: foodID) ?? "?"
        let portionSize = foodDataModel.getPortionSizeValueFromFoodID(foodID: foodID) ?? 1
        var co2ePerPortion = ""
        if co2ePerKg != "?" {
            var co2ePerPortionCalc = Double(co2ePerKg) ?? 1
            co2ePerPortionCalc *= portionSize
            co2ePerPortion = String(format: "%.1f", co2ePerPortionCalc)
            if co2ePerPortion == "0.0" {
                co2ePerPortion = "<0.1"
            }
        } else {
           co2ePerPortion = "?"
        }
        let co2ePerPortionDesc = foodDataModel.getPortionSizeTextFromFoodID(foodID: foodID) ?? "portion"
        
        foodInfoTitleLabel.text = title
        foodInfoCO2ePerKgLabel.text = co2ePerKg
        foodInfoCO2ePerPortionLabel.text = co2ePerPortion
        foodInfoCO2ePerPortionDescLabel.text = "kg CO2e per " + co2ePerPortionDesc
    }
    
    
    func setUpFoodSuggestionsView(foodID: [Int]) {

        for i in 0...(suggestionButtonsCount - 1) {
            
            suggestionButtons[i].foodID = foodID[i]
            suggestionButtons[i].setTitle(foodDataModel.getNameFromFoodID(foodID: foodID[i]) ?? "", for: .normal)
            
            suggestionButtons[i].backgroundColor = colourBg
            suggestionButtons[i].setTitleColor(colourText, for: .normal)
        }

        suggestionButtons[0].backgroundColor = colourHighlightBg
        suggestionButtons[0].setTitleColor(colourHighlightText, for: .normal)
        
        currentFoodInfoShown = 0
        scrollViewForSuggestionButtons.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
    }
    
    
    // MARK: UIButton Action Handlers
    
    @IBAction func shutterButtonTouchUp(_ sender: Any) {
        
        if !self.readyToCaptureAndProcessImage { return }
        self.readyToCaptureAndProcessImage = false
        
        // Set boolean so that next captured frame will be processed for object classification
        self.videoFrameNeedsToBeProcessed = true
    }
    
    
    @IBAction func torchButtonTapped(_ sender: Any) {
        toggleTorch()
    }
    
    
    @IBAction func foodListButtonTouchUp(_ sender: Any) {
        
        if !self.readyToCaptureAndProcessImage { return }
        self.performSegue(withIdentifier: "segueToFoodInfoViewController", sender: nil)
    }
    
    
    @IBAction func infoPanelCloseButtonTouchUp(_ sender: Any) {
        
        UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseInOut], animations: { self.infoPanelStackViewBottomConstraint.constant = -400; self.shutterButton.alpha = 1; self.torchButton.alpha = 1; self.foodListButton.alpha = 1; self.view.layoutIfNeeded() }, completion: nil)
        infoPanelVisible = false
        
        readyToCaptureAndProcessImage = true
    }
    
    
    // Handles touch-up event for all six suggestionButtons:
    @IBAction func suggestionButtonTouchUp(_ sender: Any) {
        
        // Cast sender object as FoodButton:
        
        let senderButton = sender as! FoodButton
        if currentFoodInfoShown == senderButton.suggestionButtonID { return }
        
        // Display food info for corresponding food of the tapped button:
        
        currentFoodInfoShown = senderButton.suggestionButtonID
        setUpFoodInfoView(foodID: senderButton.foodID)
        
        // Reset colouring of all suggestion buttons to default, and colour tapped suggestion button with highlight colours to indicate it was tapped:
        
        for i in 0...(suggestionButtonsCount - 1) {
            
            suggestionButtons[i].backgroundColor = colourBg
            suggestionButtons[i].setTitleColor(colourText, for: .normal)
            
            if suggestionButtons[i].suggestionButtonID == senderButton.suggestionButtonID {
                suggestionButtons[i].backgroundColor = colourHighlightBg
                suggestionButtons[i].setTitleColor(colourHighlightText, for: .normal)
            }
        }
        
        // Animate the food info panel to flip:
        
        UIView.transition(with: self.foodInfoView, duration: 0.3, options: [.transitionFlipFromLeft], animations: nil, completion: nil)
    }
    
    
    // MARK: Miscellanous Functions
    
    func showAlert(titleIn:String, msgIn:String) {
        let alert = UIAlertController(title: titleIn, message: msgIn, preferredStyle: .alert)
        let alertOkAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alert.addAction(alertOkAction)
        present(alert, animated: true, completion: nil)
    }
    
}

