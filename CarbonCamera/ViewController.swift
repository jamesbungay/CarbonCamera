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
    
    var deviceHasTorch: Bool = false
    
    let captureSession = AVCaptureSession()
    
    
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
    
    
    // MARK: Function to setup video captureSession
    
    func setUpCaptureSession() {
        
        // Setup video input to captureSession:
        
        captureSession.beginConfiguration()
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            else { return }  // Configuration failed, no back camera.
        
        self.deviceHasTorch = videoDevice.hasTorch
        
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice)
            else { return }  // Configuration failed, cannot use back camera as capture input device.
        
        if captureSession.canAddInput(videoDeviceInput) {
            captureSession.addInput(videoDeviceInput)
        } else { return }  // Configuration failed, cannot add input to captureSession.
        
        // Setup video output from captureSession:
        
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
    
    
    // MARK: Camera control button handler methods
    
    @IBAction func torchButtonTapped(_ sender: Any) {
        
        guard let videoDevice = AVCaptureDevice.default(for: .video)
            else { return }
        
        guard videoDevice.hasTorch, videoDevice.isTorchAvailable
            else { return }
        
        if videoDevice.torchMode != .on {  // Turn on torch and configure button to show this:
            do {
                try videoDevice.lockForConfiguration()
                videoDevice.torchMode = .on
                torchButton.setBackgroundImage(UIImage(systemName: "lightbulb"), for: UIControl.State.normal)
            } catch { return }  // Video device could not be reconfigured to turn on torch.
            
        } else {  // Turn off torch and configure button to show this:
            do {
                try videoDevice.lockForConfiguration()
                videoDevice.torchMode = .off
                torchButton.setBackgroundImage(UIImage(systemName: "lightbulb.slash"), for: UIControl.State.normal)
            } catch { return }  // Video device could not be reconfigured to turn off torch.
        }
        
        videoDevice.unlockForConfiguration()  // Allow other apps to reconfigure video device.
    }
    
    
    // MARK: CaptureSession Output Delegate Methods
    
    // Function called every time the camera captures a frame:
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Set up CoreML vision model, request and handler method:
        
        guard let visionModel = try? VNCoreMLModel(for: Resnet50().model)
            else { return }
        
        let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: {
            completedClassificationRequest, err in

            guard let firstObservation = completedClassificationRequest.results?.first as? VNClassificationObservation
                else { return }  // No results of classification
            
            print(firstObservation.identifier, " -- ", firstObservation.confidence)
        })
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            else { return }
        
        let bgQueue = DispatchQueue(label: "queue.serial.classificationRequestHandler")
        bgQueue.async {
            let requestHandler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, options: [:])
            try? requestHandler.perform([classificationRequest])
        }
    }
    
    
    // MARK: Miscellanous Functions
    
    func showAlert(titleIn:String, msgIn:String) {
        let alert = UIAlertController(title: titleIn, message: msgIn, preferredStyle: .alert)
        let alertOkAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alert.addAction(alertOkAction)
        present(alert, animated: true, completion: nil)
    }

}

