//
//  ViewController.swift
//  StrawberryOrNah
//
//  Created by Damon Georgiou on 1/17/19.
//  Copyright © 2019 Damon Georgiou. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML
import Vision

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
    
    private var tap: UITapGestureRecognizer?
    
    private var flashControlState: FlashState = .off
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        activityIndicator.isHidden = true
        
        tap = UITapGestureRecognizer(target: self, action: #selector(didTapCameraView))
        tap!.numberOfTapsRequired = 1
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // First we check if the device has a camera (otherwise will crash in Simulator - also, some iPod touch models do not have a camera).
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            // Then check if camera access has been allowed; alert user to allow access if access has been denied
            let authStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
            switch authStatus {
            case .authorized:
                setupCamera()
                break
            case .denied:
                alertPromptToAllowCameraAccessViaSettings()
                break
            case .notDetermined:
                break
            default:
                break
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        if (cameraView.gestureRecognizers?.count)! > 0 {
            cameraView.removeGestureRecognizer(tap!)
        }
        stopRunningCaptureSession()
    }
    
    func setupCamera() {
        setupCaptureSession()
        setupDevice()
        setupInputOutput()
        setupPreviewLayer()
        startRunningCaptureSession()
        
        cameraView.addGestureRecognizer(tap!)
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
    
    func alertPromptToAllowCameraAccessViaSettings() {
        let alert = UIAlertController(title: Constants.AllowCameraAccessAlert.TITLE, message: Constants.AllowCameraAccessAlert.MESSAGE, preferredStyle: .alert )
        alert.addAction(UIAlertAction(title: Constants.AllowCameraAccessAlert.SettingsAction.TITlE, style: .cancel) { alert in
            if let appSettingsURL = NSURL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(appSettingsURL as URL, options: [:], completionHandler: nil)
            }
        })
        present(alert, animated: true, completion: nil)
    }
    
    @objc func didTapCameraView() {
        let settings = AVCapturePhotoSettings()
        settings.previewPhotoFormat = settings.embeddedThumbnailPhotoFormat
        
        if flashControlState == .off {
            settings.flashMode = .off
        } else {
            settings.flashMode = .on
        }
        
        cameraOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func resultsMethod(request: VNRequest, error: Error?) {
        // Handle changing label text
        guard let results = request.results as? [VNClassificationObservation] else { return }
        
        for classification in results {
            if classification.confidence < 0.5 {
                self.identificationLbl.text = Constants.ImageClassifier.IDENTIFICATION_UNKNOWN
                self.confidenceLbl.text = ""
                break
            } else {
                let identification = classification.identifier
                let confidence = Int(classification.confidence * 100)
                if identification == Constants.ImageClassifier.IDENTIFICATION_STRAWBERRY {
                    self.identificationLbl.text = Constants.ImageClassifier.IDENTIFICATION_STRAWBERRY_LBL
                    self.confidenceLbl.text = Constants.ImageClassifier.CONFIDENCE + "\(confidence)%"
                    break
                } else {
                    self.identificationLbl.text = Constants.ImageClassifier.IDENTIFICATION_NOT_STRAWBERRY_LBL
                    self.confidenceLbl.text = Constants.ImageClassifier.CONFIDENCE + "\(confidence)%"
                    break
                }
            }
        }
    }
    

    @IBAction func flashBtnWasPressed(_ sender: Any) {
        switch flashControlState {
        case .off:
            flashBtn.setTitle(Constants.FlashState.FLASH_ON, for: .normal)
            flashControlState = .on
        case .on:
            flashBtn.setTitle(Constants.FlashState.FLASH_OFF, for: .normal)
            flashControlState = .off
        }
    }
    
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            debugPrint(error)
        } else {
            photoData = photo.fileDataRepresentation()
            
            do {
                let model = try VNCoreMLModel(for: StrawberryImageClassifier().model)
                let request = VNCoreMLRequest(model: model, completionHandler: resultsMethod)
                let handler = VNImageRequestHandler(data: photoData!)
                try handler.perform([request])
            } catch {
                // Handle errors
                debugPrint(error)
            }
            
            let image = UIImage(data: photoData!)
            self.capturedImageView.image = image
        }
    }
}

enum FlashState {
    case off
    case on
}
