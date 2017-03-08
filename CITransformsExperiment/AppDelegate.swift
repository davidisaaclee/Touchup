//
//  AppDelegate.swift
//  CITransformsExperiment
//
//  Created by David Lee on 2/28/17.
//  Copyright © 2017 David Lee. All rights reserved.
//

import UIKit
import Mixpanel

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		BuddyBuildSDK.setup()
		Analytics.shared.setup()

		return true
	}

}

class Analytics {
	static let shared = Analytics()

	enum Event: String {
		case beganImportFromPhotos
		case finishedImportFromPhotos
		case cancelledImportFromPhotos

		case beganImportFromCamera
		case finishedImportFromCamera
		case cancelledImportFromCamera

		case beganExport
		case finishedExport
		case cancelledExport

		case stampToBackground

		var name: String {
			return rawValue
		}
	}

	private var mixpanel: MixpanelInstance?

	func setup() {
		mixpanel = Mixpanel.initialize(token: "3a201f871093e667887cfa7f0ff85c33")
	}

	func track(_ event: Event) {
		guard let mixpanel = mixpanel else {
			return
		}

		mixpanel.track(event: event.name)
	}
}

