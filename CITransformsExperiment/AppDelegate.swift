//
//  AppDelegate.swift
//  CITransformsExperiment
//
//  Created by David Lee on 2/28/17.
//  Copyright © 2017 David Lee. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		BuddyBuildSDK.setup()
		Analytics.shared.setup()

		#if DEBUG
			print("Running debug scheme")
		#else
			print("Running release scheme")
		#endif

		return true
	}

}

