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
    
    private var flashControlState: Constants.FlashState.FlashState = .off
    
    private var speechSynthesizer = AVSpeechSynthesizer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        speechSynthesizer.delegate = self
        
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
        
        // Add gestureRecognizer to take photo once captureSession is setup and running
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
        // Run capture session if capture session is not running
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    func stopRunningCaptureSession() {
        // Stop running capture session if capture session is running
        if captureSession.isRunning {
            captureSession.stopRunning()
            // Remove capture session input if capture session input exists
            if captureSession.inputs.count > 0 {
                captureSession.removeInput(captureDeviceInput!)
            }
            // Remove capture session output if capture session output exists
            if captureSession.outputs.count > 0 {
                captureSession.removeOutput(cameraOutput!)
            }
        }
    }
    
    func alertPromptToAllowCameraAccessViaSettings() {
        // Instantiate alert controller to send user to Settings to change apps Camera Permission
        let alert = UIAlertController(title: Constants.AllowCameraAccessAlert.TITLE, message: Constants.AllowCameraAccessAlert.MESSAGE, preferredStyle: .alert )
        // Add action which sends user to Settings to change apps Camera Permission
        alert.addAction(UIAlertAction(title: Constants.AllowCameraAccessAlert.SettingsAction.TITlE, style: .cancel) { alert in
            if let appSettingsURL = NSURL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(appSettingsURL as URL, options: [:], completionHandler: nil)
            }
        })
        // Present Camera Permission alert controller
        present(alert, animated: true, completion: nil)
    }
    
    @objc func didTapCameraView() {
        // Disable another photo from being taken and animate/show activity indicator until image classification and speech is complete
        cameraView.isUserInteractionEnabled = false
        activityIndicator.startAnimating()
        activityIndicator.isHidden = false
        
        // Set AVCapturePhotoSettings settings
        let settings = AVCapturePhotoSettings()
        settings.previewPhotoFormat = settings.embeddedThumbnailPhotoFormat
        // Update AVCapturePhotoSettings settings with respective flash state
        if flashControlState == .off {
            settings.flashMode = .off
        } else {
            settings.flashMode = .on
        }
        
        // Capture photo
        cameraOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func resultsMethod(request: VNRequest, error: Error?) {
        // Handle changing label text and speak image classification results
        guard let results = request.results as? [VNClassificationObservation] else { return }
        
        // Determine image classification results
        for classification in results {
            // Image classifier IS NOT confident on results, return with .IDENTIFICATION_UNKNOWN
            if classification.confidence < 0.5 {
                self.identificationLbl.text = Constants.ImageClassifier.IDENTIFICATION_UNKNOWN
                self.confidenceLbl.text = ""
                synthensizeSpeech(fromString: Constants.ImageClassifier.IDENTIFICATION_UNKNOWN)
                break
            } else {
                // Image classifier IS confident on results, return with identification of image
                // Get image classifier identification
                let identification = classification.identifier
                // Get image classifier confidence level, multiply result by 100 to put it the form of a percentage
                let confidence = Int(classification.confidence * 100)
                
                if identification == Constants.ImageClassifier.IDENTIFICATION_STRAWBERRY {
                    // Image classifier identified image as a strawberry; update UI respectively and speak results
                    self.identificationLbl.text = Constants.ImageClassifier.IDENTIFICATION_STRAWBERRY_LBL
                    self.confidenceLbl.text = Constants.ImageClassifier.CONFIDENCE + "\(confidence)%"
                    synthensizeSpeech(fromString: Constants.ImageClassifier.IDENTIFICATION_STRAWBERRY_LBL)
                    break
                } else {
                    // Image classifier identified image as not a strawberry; update UI respectively and speak results
                    self.identificationLbl.text = Constants.ImageClassifier.IDENTIFICATION_NOT_STRAWBERRY_LBL
                    self.confidenceLbl.text = Constants.ImageClassifier.CONFIDENCE + "\(confidence)%"
                    synthensizeSpeech(fromString: Constants.ImageClassifier.IDENTIFICATION_NOT_STRAWBERRY_LBL)
                    break
                }
            }
        }
    }
    
    func synthensizeSpeech(fromString string: String) {
        // Speak image classification result
        let speechUtterance = AVSpeechUtterance(string: string)
        speechSynthesizer.speak(speechUtterance)
    }
    

    @IBAction func flashBtnWasPressed(_ sender: Any) {
        // Toggle flashBtn text and flashState
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
            // Convert AVCapturePhoto into Data for image classification
            photoData = photo.fileDataRepresentation()
            
            // Setup CoreML and pass photo data into image classifier
            do {
                let model = try VNCoreMLModel(for: StrawberryImageClassifier().model)
                let request = VNCoreMLRequest(model: model, completionHandler: resultsMethod)
                let handler = VNImageRequestHandler(data: photoData!)
                try handler.perform([request])
            } catch {
                // Handle errors
                debugPrint(error)
            }
            
            // Update UI with photo data
            let image = UIImage(data: photoData!)
            self.capturedImageView.image = image
        }
    }
}

extension CameraViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Speech utterance is finished, hide/stopAnimating activity indicator and allow user to take a new photo
        cameraView.isUserInteractionEnabled = true
        activityIndicator.isHidden = true
        activityIndicator.stopAnimating()
    }
}
