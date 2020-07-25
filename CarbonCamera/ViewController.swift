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


// TODO: Reset torch button image when app comes back into view after being suspended


class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var cameraPreviewView: CameraPreviewView!
    
    @IBOutlet weak var torchButton: UIButton!
    @IBOutlet weak var shutterButton: UIButton!
    
    // TODO: add outlet for suggestion buttons and food info labels
    
    @IBOutlet weak var classificationResultLabel: UILabel!
    
    @IBOutlet weak var infoPanelStackViewBottomConstraint: NSLayoutConstraint!
    
    
    var deviceHasTorch: Bool = false
    
    let captureSession = AVCaptureSession()
    
    var infoPanelVisible = true
    
    var videoFrameNeedsToBeProcessed = false  // Toggled true when shutter button pressed
    var readyToCaptureAndProcessImage = true  // Toggled true when no image is currently being pressed and info panel is not visible
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Verify authorisation for video capture, and then set up captureSession:
        
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized || AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            self.setUpCaptureSession()
        }
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
    
    
    // MARK: captureSession setup method
    
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
    
    
    // MARK: Torch toggle method
    
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
    
    
    
    
    
    
    
    
    
    // MARK: CaptureSession Continous Video Output Delegate Method
    
    // Function called every time the camera captures a frame:
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if !videoFrameNeedsToBeProcessed { return }
        videoFrameNeedsToBeProcessed = false  // A frame of video is now being handled in response to the shutter button being pressed, so no longer need to process another hense this boolean is set
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            else { return }
        
        classifyImageAndPassResultsToHandler(imageBufferIn: imageBuffer)
    }
    
    
    func classifyImageAndPassResultsToHandler(imageBufferIn: CVImageBuffer) {
        
        // Set up CoreML vision model, request and handler method:
        
        guard let visionModel = try? VNCoreMLModel(for: Resnet50().model)
            else { return }
        
        let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: {
            completedClassificationRequest, err in

            guard let results = completedClassificationRequest.results as? [VNClassificationObservation]
                else { return }
            
            self.handleResultsOfClassification(results: results)
            
            //TODO: remove
            // Display result of classification in UI; do work on main thread
            DispatchQueue.main.async {
                self.classificationResultLabel.text = String(results[0].identifier + " -- " + String(results[0].confidence))
                self.classificationResultLabel.text! += String("\n" + results[1].identifier + " -- " + String(results[1].confidence))
            }
        })
        
        let bgQueue = DispatchQueue(label: "queue.serial.classificationRequestHandler")
        bgQueue.async {
            let requestHandler = VNImageRequestHandler(cvPixelBuffer: imageBufferIn, options: [:])
            try? requestHandler.perform([classificationRequest])
        }
    }
    
    
    func handleResultsOfClassification(results: [VNClassificationObservation]) {
        
        // Get foodIDs of top 6 classification results that are foods, still working off main queue/thread to prevent the UI from hanging:
        
        // TODO: UNCOMMENT WHEN FOOD DATASET IS ADDED TO PROJECT
//        var top6FoodIDs: [Int] = []
//        var foodIDsLeftToObtain = 6
//        var count = 0
//        while foodIDsLeftToObtain > 0 {
//            let returnedFoodID = getFoodIDOf(classificationIdentifier: results[count].identifier)
//            if returnedFoodID != -1 {
//                top6FoodIDs.append(returnedFoodID)
//                foodIDsLeftToObtain -= 1
//            }
//            count += 1
//        }
        
        // Make UI changes on main thread to display results such as C02e and suggested foods:
        
        DispatchQueue.main.async {
            
            // TODO: UNCOMMENT WHEN FOOD DATASET IS ADDED TO PROJECT
//            self.setUpFoodInfoView(foodID: top6FoodIDs[0])
//            self.setUpFoodSuggestionsView(foodID: Array(top6FoodIDs.dropFirst(1)))
            
            // Display info panel on screen:
            UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseInOut], animations: { self.infoPanelStackViewBottomConstraint.constant = 10; self.shutterButton.alpha = 0; self.view.layoutIfNeeded() }, completion: nil)
            self.infoPanelVisible = true
        }
    }
    
    
    func getFoodIDOf(classificationIdentifier: String) -> Int {  // Returns -1 if input classificationIdenfitier was not in food-info-datafile
        
        // TODO: Retrieve FoodID of input identifier
        return -1
    }
    
    func setUpFoodInfoView(foodID: Int) {
        // TODO: Retrieve and display CO2e info for top result
    }
    
    func setUpFoodSuggestionsView(foodID: [Int]) {
        // TODO: make this, set buttons to other foods
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
    
    
    @IBAction func infoPanelCloseButtonTouchUp(_ sender: Any) {
        
        UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseInOut], animations: { self.infoPanelStackViewBottomConstraint.constant = -400; self.shutterButton.alpha = 1; self.view.layoutIfNeeded() }, completion: nil)
        infoPanelVisible = false
        
        readyToCaptureAndProcessImage = true
    }
    
    
    // MARK: Miscellanous Functions
    
    func showAlert(titleIn:String, msgIn:String) {
        let alert = UIAlertController(title: titleIn, message: msgIn, preferredStyle: .alert)
        let alertOkAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alert.addAction(alertOkAction)
        present(alert, animated: true, completion: nil)
    }
    
}

