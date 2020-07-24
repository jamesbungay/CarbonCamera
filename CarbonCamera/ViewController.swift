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
        // Do any additional setup after loading the view.
        
        // MARK: Setup video captureSession
        
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


}

