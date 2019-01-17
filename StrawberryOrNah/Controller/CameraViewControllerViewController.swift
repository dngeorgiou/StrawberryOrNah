//
//  ViewController.swift
//  StrawberryOrNah
//
//  Created by Damon Georgiou on 1/17/19.
//  Copyright © 2019 Damon Georgiou. All rights reserved.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController {
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var capturedImageView: RoundedShadowUIImageView!
    @IBOutlet weak var flashBtn: RoundedShadowUIButton!
    @IBOutlet weak var roundedLblView: RoundedShadowUIView!
    @IBOutlet weak var identificationLbl: UILabel!
    @IBOutlet weak var confidenceLbl: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private var captureSession: AVCaptureSession!
    private var backCamera: AVCaptureDevice?
    private var captureDeviceInput: AVCaptureDeviceInput?
    private var cameraOutput: AVCapturePhotoOutput!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    private var photoData: Data?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        setupCaptureSession()
        setupDevice()
        setupInputOutput()
        setupPreviewLayer()
        startRunningCaptureSession()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        stopRunningCaptureSession()
    }
    
    func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1920x1080
    }
    
    func setupDevice() {
        backCamera = AVCaptureDevice.default(for: AVMediaType.video)
    }
    
    func setupInputOutput() {
        do {
            let input = try AVCaptureDeviceInput(device: backCamera!)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            cameraOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(cameraOutput) {
                captureSession.addOutput(cameraOutput)
            }
        } catch {
            debugPrint(error)
        }
    }
    
    func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        previewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        previewLayer.frame = cameraView.bounds
        
        cameraView.layer.addSublayer(previewLayer)
    }
    
    func startRunningCaptureSession() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    func stopRunningCaptureSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
            if captureSession.inputs.count > 0 {
                captureSession.removeInput(captureDeviceInput!)
            }
            if captureSession.outputs.count > 0 {
                captureSession.removeOutput(cameraOutput!)
            }
        }
    }
    

    @IBAction func flashBtnWasPressed(_ sender: Any) {
    }
    
}

