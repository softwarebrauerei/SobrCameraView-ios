# THIS REPOSITORY WILL NO LONGER BE MAINTAINED BY THE DEVELOPER.
Feel free to fork and enhance it.

SobrCameraView for iOS
======================
A simple UIView-Subclass which enables border detection of documents. Based on [IPDFCameraViewController of Maximilian Mackh](https://github.com/mmackh/IPDFCameraViewController), rewritten in Swift and added some enhancements.

## Features
- Live border detection
- Flash / Torch
- Image Filters for better scanning results
- Easy to use with a simple API

## Requirements
- iOS 8.0+
- Xcode 6.3

## Communication
- If you **found a bug**, open an issue.
- If you **have a feature request**, open an issue.
- If you **want to contribute**, submit a pull request.

## Installation

> **Embedded frameworks require a minimum deployment target of iOS 8.**

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects.

CocoaPods 0.36 adds supports for Swift and embedded frameworks. You can install it with the following command:

```bash
$ gem install cocoapods
```

To integrate SobrCameraView into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
use_frameworks!

pod 'SobrCameraView'
```

Then, run the following command:

```bash
$ pod install
```

## Usage
### Using Storyboards
1. Place a UIView into your UIViewController and set the custom class to `SobrCameraView`.
![Storyboard-Screenshot](https://raw.githubusercontent.com/softwarebrauerei/SobrCameraView-ios/master/assets/storyboard-custom-class.jpg)
2. In your UIViewcontroller implement the following lines of code. (See `MainViewController.swift` in the Example App.)
	```Swift
	class MainViewController: UIViewController {
		@IBOutlet weak var cameraView: SobrCameraView!

		override func viewDidLoad() {
		    super.viewDidLoad()
		    self.cameraView.setupCameraView()
		    self.cameraView.borderDetectionEnabled = true
		}

		override func viewDidAppear(animated: Bool) {
	        super.viewDidAppear(animated)
	        self.cameraView.start()
	    }

	    override func viewWillDisappear(animated: Bool) {
	        super.viewWillDisappear(animated)
	        self.cameraView.stop()
	    }
	}
	```
3. Connect the outlet in your storyboard.  
4. Run the app on a device and you will see a camera picture on your screen.

For more usage details please have a look at the example project.



## Authors
- Silas Knobel, https://github.com/katunch

## License

SobrCameraView is available under the MIT license. See the LICENSE file for more info.
