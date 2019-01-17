//
//  Constants.swift
//  StrawberryOrNah
//
//  Created by Damon Georgiou on 1/17/19.
//  Copyright © 2019 Damon Georgiou. All rights reserved.
//

struct Constants {
    struct AllowCameraAccessAlert {
        static let TITLE = "StrawberryOrNah Would Like To Access the Camera"
        static let MESSAGE = "StrawberryOrNah needs camera access to take photos and identify objects."
        
        struct SettingsAction {
            static let TITlE = "Open Settings"
        }
    }
    
    struct FlashState {
        static let FLASH_ON = "FLASH ON"
        static let FLASH_OFF = "FLASH OFF"
        
        enum FlashState {
            case off
            case on
        }
    }
    
    struct ImageClassifier {
        static let IDENTIFICATION_UNKNOWN = "I'm not sure what this is. Please try again."
        static let IDENTIFICATION_STRAWBERRY = "strawberry"
        static let IDENTIFICATION_STRAWBERRY_LBL = "Strawberry"
        static let IDENTIFICATION_NOT_STRAWBERRY_LBL = "Not a strawberry"
        static let CONFIDENCE = "CONFIDENCE: "
    }
}
