//
//  Copyright (C) 2015 Google, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import GoogleMobileAds
import UIKit

class NativeViewController: UIViewController {

    /// The view that holds the native ad.
    @IBOutlet weak var nativeAdPlaceholder: UIView!

    /// Indicates whether videos should start muted.
    @IBOutlet weak var startMutedSwitch: UISwitch!

    /// The refresh ad button.
    @IBOutlet weak var refreshAdButton: UIButton!

    /// Displays the current status of video assets.
    @IBOutlet weak var videoStatusLabel: UILabel!

    /// The SDK version label.
    @IBOutlet weak var versionLabel: UILabel!

    /// The height constraint applied to the ad view, where necessary.
    var heightConstraint : NSLayoutConstraint?

    /// The ad loader. You must keep a strong reference to the GADAdLoader during the ad loading
    /// process.
    var adLoader: GADAdLoader!

    /// The native ad view that is being presented.
    var nativeAdView: GADUnifiedNativeAdView!

    /// The ad unit ID.
    let adUnitID = "/21715142772/GAANA_APP_TEST/Gaana_App_Test_Native_new"

    override func viewDidLoad() {
        super.viewDidLoad()
        versionLabel.text = GADRequest.sdkVersion()
        guard let nibObjects = Bundle.main.loadNibNamed("UnifiedNativeAdView", owner: nil, options: nil),
            let adView = nibObjects.first as? GADUnifiedNativeAdView else {
                assert(false, "Could not load nib file for adView")
        }
        setAdView(adView)
        refreshAd(nil)
    }


    func setAdView(_ view: GADUnifiedNativeAdView) {
        // Remove the previous ad view.
        nativeAdView = view
        nativeAdPlaceholder.addSubview(nativeAdView)
        nativeAdView.translatesAutoresizingMaskIntoConstraints = false

        // Layout constraints for positioning the native ad view to stretch the entire width and height
        // of the nativeAdPlaceholder.
        let viewDictionary = ["_nativeAdView": nativeAdView!]
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_nativeAdView]|",
                                                                options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewDictionary))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[_nativeAdView]|",
                                                                options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewDictionary))
    }

    // MARK: - Actions

    /// Refreshes the native ad.
    @IBAction func refreshAd(_ sender: AnyObject!) {
        refreshAdButton.isEnabled = false
        videoStatusLabel.text = ""
        adLoader = GADAdLoader(adUnitID: adUnitID, rootViewController: self,
                               adTypes: [ .unifiedNative ], options: nil)
        adLoader.delegate = self
        let request = GADRequest()
        request.testDevices = [""]
        adLoader.load(request)
    }

    /// Returns a `UIImage` representing the number of stars from the given star rating; returns `nil`
    /// if the star rating is less than 3.5 stars.
    func imageOfStars(from starRating: NSDecimalNumber?) -> UIImage? {
        guard let rating = starRating?.doubleValue else {
            return nil
        }
        if rating >= 5 {
            return UIImage(named: "stars_5")
        } else if rating >= 4.5 {
            return UIImage(named: "stars_4_5")
        } else if rating >= 4 {
            return UIImage(named: "stars_4")
        } else if rating >= 3.5 {
            return UIImage(named: "stars_3_5")
        } else {
            return nil
        }
    }
}

extension NativeViewController : GADVideoControllerDelegate {

    func videoControllerDidEndVideoPlayback(_ videoController: GADVideoController) {
        videoStatusLabel.text = "Video playback has ended."
    }
}

extension NativeViewController : GADAdLoaderDelegate {

    func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: GADRequestError) {
        print("\(adLoader) failed with error: \(error.localizedDescription)")
        refreshAdButton.isEnabled = true
    }
}

extension NativeViewController : GADUnifiedNativeAdLoaderDelegate {

    func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADUnifiedNativeAd) {
        refreshAdButton.isEnabled = true
        nativeAdView.nativeAd = nativeAd

        // Set ourselves as the native ad delegate to be notified of native ad events.
        nativeAd.delegate = self

        // Deactivate the height constraint that was set when the previous video ad loaded.
        heightConstraint?.isActive = false

        // Populate the native ad view with the native ad assets.
        // The headline is guaranteed to be present in every native ad.
        (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline

        // Some native ads will include a video asset, while others do not. Apps can use the
        // GADVideoController's hasVideoContent property to determine if one is present, and adjust their
        // UI accordingly.
        if let controller = nativeAd.videoController, controller.hasVideoContent() {
            // The video controller has content. Show the media view.
            if let mediaView = nativeAdView.mediaView {
                // This app uses a fixed width for the GADMediaView and changes its height to match the aspect
                // ratio of the video it displays.
                if controller.aspectRatio() > 0 {
                    heightConstraint = NSLayoutConstraint(item: mediaView,
                                                          attribute: .height,
                                                          relatedBy: .equal,
                                                          toItem: mediaView,
                                                          attribute: .width,
                                                          multiplier: CGFloat(1 / controller.aspectRatio()),
                                                          constant: 0)
                    heightConstraint?.isActive = true
                }
            }
            // By acting as the delegate to the GADVideoController, this ViewController receives messages
            // about events in the video lifecycle.
            controller.delegate = self
            videoStatusLabel.text = "Ad contains a video asset."
        }
        else {
            videoStatusLabel.text = "Ad does not contain a video."
        }

        // These assets are not guaranteed to be present. Check that they are before
        // showing or hiding them.
        (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body
        nativeAdView.bodyView?.isHidden = nativeAd.body == nil

        (nativeAdView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        nativeAdView.callToActionView?.isHidden = nativeAd.callToAction == nil

        (nativeAdView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        nativeAdView.iconView?.isHidden = nativeAd.icon == nil

        (nativeAdView.starRatingView as? UIImageView)?.image = imageOfStars(from:nativeAd.starRating)
        nativeAdView.starRatingView?.isHidden = nativeAd.starRating == nil

        (nativeAdView.storeView as? UILabel)?.text = nativeAd.store
        nativeAdView.storeView?.isHidden = nativeAd.store == nil

        (nativeAdView.priceView as? UILabel)?.text = nativeAd.price
        nativeAdView.priceView?.isHidden = nativeAd.price == nil

        (nativeAdView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        nativeAdView.advertiserView?.isHidden = nativeAd.advertiser == nil

        // In order for the SDK to process touch events properly, user interaction should be disabled.
        nativeAdView.callToActionView?.isUserInteractionEnabled = false
    }
}

// MARK: - GADUnifiedNativeAdDelegate implementation
extension NativeViewController : GADUnifiedNativeAdDelegate {

    func nativeAdDidRecordClick(_ nativeAd: GADUnifiedNativeAd) {
        print("\(#function) called")
    }

    func nativeAdDidRecordImpression(_ nativeAd: GADUnifiedNativeAd) {
        print("\(#function) called")
    }

    func nativeAdWillPresentScreen(_ nativeAd: GADUnifiedNativeAd) {
        print("\(#function) called")
    }

    func nativeAdWillDismissScreen(_ nativeAd: GADUnifiedNativeAd) {
        print("\(#function) called")
    }

    func nativeAdDidDismissScreen(_ nativeAd: GADUnifiedNativeAd) {
        print("\(#function) called")
    }

    func nativeAdWillLeaveApplication(_ nativeAd: GADUnifiedNativeAd) {
        print("\(#function) called")
    }
}
