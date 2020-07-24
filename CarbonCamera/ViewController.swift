//
//  ViewController.swift
//  CarbonCamera
//
//  Created by James Bungay on 22/07/2020.
//  Copyright © 2020 James Bungay. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet weak var cameraPreviewView: CameraPreviewView!
    
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
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        } else { return }
        
        // Setup preview for captureSession:
        cameraPreviewView.videoPreviewLayer.session = captureSession
        cameraPreviewView.videoPreviewLayer.videoGravity = .resizeAspectFill  // Set video preview to fill the view
        
        captureSession.commitConfiguration()
        let serialQueue = DispatchQueue(label: "com.queue.serial")
        serialQueue.async {
            self.captureSession.startRunning()
        }
    }
    
    
    func showAlert(titleIn:String, msgIn:String) {
        let alert = UIAlertController(title: titleIn, message: msgIn, preferredStyle: .alert)
        let alertOkAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alert.addAction(alertOkAction)
        present(alert, animated: true, completion: nil)
    }

}

