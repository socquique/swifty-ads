
//  Created by Dominik on 22/08/2015.

//    The MIT License (MIT)
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.

//    v4.1

//    Dont forget to add the custom "-D DEBUG" flag in Targets -> BuildSettings -> SwiftCompiler-CustomFlags -> DEBUG)

/*
    Abstract:
    A Singleton class to manage banner and interstitial adverts from AdMob. This class is only included in the iOS version of the project.
*/

import GoogleMobileAds

/// Hide print statements for release
private struct Debug {
    static func print(object: Any) {
        #if DEBUG
            Swift.print("DEBUG", object) //, terminator: "")
        #endif
    }
}

/// Admob ad unit IDs
private enum AdUnitID: String {
    // Real IDs
    #if !DEBUG
    case Banner = "Enter your real banner adUnitID"
    case Inter = "Enter your real inter adUnitID"
    case RewardVideo = "Enter your real reward video adUnitID"
    // Test IDs
    #else
    case Banner = "ca-app-pub-3940256099942544/2934735716"
    case Inter = "ca-app-pub-3940256099942544/4411468910"
    case RewardVideo = "ca-app-pub-1234567890123456/1234567890"
    #endif
}

/// Delegates
protocol AdMobDelegate: class {
    func adMobAdClicked()
    func adMobAdClosed()
    func adMobDidRewardUser(rewardAmount rewardAmount: Int)
}

protocol AdMobErrorDelegate: class {
    func adMobBannerFail()
    func adMobInterFail()
}

/// Ads singleton class
class AdMob: NSObject {
    
    // MARK: - Static Properties
    
    /// Shared instance
    static let sharedInstance = AdMob()
    
    // MARK: - Properties
    
    /// Delegates
    weak var delegate: AdMobDelegate?
    weak var errorDelegate: AdMobErrorDelegate?
    
    /// Check if reward video is ready
    var rewardVideoIsReady: Bool {
        guard let rewardVideoAd = rewardVideoAd else { return false }
        return rewardVideoAd.ready
    }
    
    /// Presenting view controller
    private var presentingViewController: UIViewController?
    
    /// Removed ads
    private var removedAds = false
    
    /// Ads
    private var bannerAdView: GADBannerView?
    private var interAd: GADInterstitial?
    private var rewardVideoAd: GADRewardBasedVideoAd?
    
    
    // MARK: - Init
    
    private override init() {
        super.init()
        Debug.print("Google Mobile Ads SDK version: " + GADRequest.sdkVersion())
        
        // Preload inter and reward ads first time
        interAd = loadInterAd()
        rewardVideoAd = loadRewardAd()
    }
    
    // MARK: - User Methods
    
    /// SetUp
    func setUp(viewController viewController: UIViewController) {
        presentingViewController = viewController
    }
    
    /// Show banner ad with delay
    func showBannerWithDelay(delay: NSTimeInterval) {
        guard !removedAds else { return }
        NSTimer.scheduledTimerWithTimeInterval(delay, target: self, selector: #selector(showBanner), userInfo: nil, repeats: false)
    }
    
    /// Show banner ad
    func showBanner() {
        guard !removedAds else { return }
        loadBannerAd()
    }
    
    /// Show inter ad randomly
    func showInterRandomly(randomness randomness: UInt32) {
        guard !removedAds else { return }
        
        let randomInterAd = Int(arc4random_uniform(randomness)) // get a random number between 0 and 2, so 33%
        guard randomInterAd == 0 else { return }
        showInterAd()
    }
    
    /// Show inter ad
    func showInter() {
        guard !removedAds else { return }
        showInterAd()
    }
    
    /// Show reward video ad
    func showRewardVideo() {
        guard !removedAds else { return }
        showRewardAd()
    }
    
    /// Remove banner ads
    func removeBanner() {
        bannerAdView?.delegate = nil
        bannerAdView?.removeFromSuperview()
        
        guard let view = presentingViewController?.view else { return }
        
        for subview in view.subviews {
            if let adMobBanner = subview as? GADBannerView {
                adMobBanner.delegate = nil
                adMobBanner.removeFromSuperview()
            }
        }
    }
    
    /// Remove all ads (IAPs)
    func removeAll() {
        Debug.print("Removed all ads")
        removedAds = true
        removeBanner()
        interAd?.delegate = nil
        rewardVideoAd?.delegate = nil
    }
    
    /// Orientation changed
    func orientationChanged() {
        guard let presentingViewController = presentingViewController else { return }
        
        if UIApplication.sharedApplication().statusBarOrientation.isLandscape {
            bannerAdView?.adSize = kGADAdSizeSmartBannerLandscape
        } else {
            bannerAdView?.adSize = kGADAdSizeSmartBannerPortrait
        }
        bannerAdView?.center = CGPoint(x: CGRectGetMidX(presentingViewController.view.frame), y: CGRectGetMaxY(presentingViewController.view.frame) - (bannerAdView!.frame.size.height / 2))
    }
}

// MARK: - Private Methods
private extension AdMob {
    
    /// Banner
    func loadBannerAd() {
        guard let presentingViewController = presentingViewController else { return }
        Debug.print("AdMob banner loading...")
        
        if UIApplication.sharedApplication().statusBarOrientation.isLandscape {
            bannerAdView = GADBannerView(adSize: kGADAdSizeSmartBannerLandscape)
        } else {
            bannerAdView = GADBannerView(adSize: kGADAdSizeSmartBannerPortrait)
        }
        
        bannerAdView?.adUnitID = AdUnitID.Banner.rawValue
        bannerAdView?.delegate = self
        bannerAdView?.rootViewController = presentingViewController
        bannerAdView?.center = CGPoint(x: CGRectGetMidX(presentingViewController.view.frame), y: CGRectGetMaxY(presentingViewController.view.frame) + (bannerAdView!.frame.size.height / 2))
        
        let request = GADRequest()
        
        #if DEBUG
            request.testDevices = [kGADSimulatorID]
        #endif
        
        bannerAdView?.loadRequest(request)
    }
    
    /// Inter
    func loadInterAd() -> GADInterstitial {
        Debug.print("AdMob inter loading...")
        
        let interAd = GADInterstitial(adUnitID: AdUnitID.Inter.rawValue)
        interAd.delegate = self
        
        let request = GADRequest()
        
        #if DEBUG
            request.testDevices = [kGADSimulatorID]
        #endif
        
        interAd.loadRequest(request)
        
        return interAd
    }
    
    func showInterAd() {
        guard interAd != nil && interAd!.isReady else {
            Debug.print("AdMob inter is not ready, reloading")
            interAd = loadInterAd() // do not try iAd again incase of error with both and than they show at the wrong time
            return
        }
        
        Debug.print("AdMob inter showing...")
        guard let rootViewController = presentingViewController?.view?.window?.rootViewController else { return }
        interAd?.presentFromRootViewController(rootViewController)
    }
    
    /// Reward video
    func loadRewardAd() -> GADRewardBasedVideoAd {
        
        let rewardVideoAd = GADRewardBasedVideoAd.sharedInstance()
        
        rewardVideoAd.delegate = self
        let request = GADRequest()
        
        #if DEBUG
            request.testDevices = [kGADSimulatorID]
        #endif
        
        rewardVideoAd.loadRequest(request, withAdUnitID: AdUnitID.RewardVideo.rawValue)
        
        return rewardVideoAd
    }
    
    func showRewardAd() {
        guard rewardVideoAd != nil && rewardVideoAd!.ready else {
            Debug.print("AdMob reward video is not ready, reloading")
            rewardVideoAd = loadRewardAd()
            return
        }
        
        guard let rootViewController = presentingViewController else { return }
        rewardVideoAd?.presentFromRootViewController(rootViewController)
    }
}

// MARK: - Banner Delegates
extension AdMob: GADBannerViewDelegate {
    
    func adViewDidReceiveAd(bannerView: GADBannerView!) {
        Debug.print("Banner adapter class name: \(bannerView.adNetworkClassName)")
        guard let presentingViewController = presentingViewController else { return }
        Debug.print("AdMob banner did load, showing")
        
        presentingViewController.view?.window?.rootViewController?.view.addSubview(bannerView)
        UIView.beginAnimations(nil, context: nil)
        UIView.setAnimationDuration(1.5)
        bannerView.center = CGPoint(x: CGRectGetMidX(presentingViewController.view.frame), y: CGRectGetMaxY(presentingViewController.view.frame) - (bannerView.frame.size.height / 2))
        UIView.commitAnimations()
    }
    
    func adViewWillPresentScreen(bannerView: GADBannerView!) { // only get called in release mode
        Debug.print("AdMob banner clicked")
        delegate?.adMobAdClicked()
    }
    
    func adViewDidDismissScreen(bannerView: GADBannerView!) { // only get called in release mode
        Debug.print("AdMob banner closed")
        delegate?.adMobAdClosed()
    }
    
    func adView(bannerView: GADBannerView!, didFailToReceiveAdWithError error: GADRequestError!) {
        Debug.print(error.localizedDescription)
        guard let presentingViewController = presentingViewController else { return }
        
        UIView.beginAnimations(nil, context: nil)
        UIView.setAnimationDuration(1.5)
        bannerView.center = CGPoint(x: CGRectGetMidX(presentingViewController.view.frame), y: CGRectGetMaxY(presentingViewController.view.frame) + (bannerView.frame.size.height / 2))
        bannerView.hidden = true
        
        errorDelegate?.adMobBannerFail()
        
        UIView.commitAnimations()
    }
}

// MARK: - Inter Delegates
extension AdMob: GADInterstitialDelegate {
    
    func interstitialDidReceiveAd(ad: GADInterstitial!) {
        Debug.print("Interstitial adapter class name: \(ad.adNetworkClassName)")
        Debug.print("AdMob inter did load")
    }
    
    func interstitialWillPresentScreen(ad: GADInterstitial!) {
        Debug.print("AdMob inter will present")
    }
    
    func interstitialWillDismissScreen(ad: GADInterstitial!) {
        Debug.print("AdMob inter about to be closed")
    }
    
    func interstitialDidDismissScreen(ad: GADInterstitial!) {
        Debug.print("AdMob inter closed")
        interAd = loadInterAd()
    }
    
    func interstitialWillLeaveApplication(ad: GADInterstitial!) {
        Debug.print("AdMob inter about to leave app")
    }
    
    func interstitial(ad: GADInterstitial!, didFailToReceiveAdWithError error: GADRequestError!) {
        Debug.print("AdMob inter error")
        errorDelegate?.adMobInterFail()
    }
}

// MARK: - Reward Video Delegates
extension AdMob: GADRewardBasedVideoAdDelegate {
    
    func rewardBasedVideoAdDidOpen(rewardBasedVideoAd: GADRewardBasedVideoAd!) {
        Debug.print("AdMob reward video ad  did open")
    }
    
    func rewardBasedVideoAdDidClose(rewardBasedVideoAd: GADRewardBasedVideoAd!) {
        Debug.print("AdMob reward video ad  did close")
        delegate?.adMobAdClosed()
        rewardVideoAd = loadRewardAd()
    }
    
    func rewardBasedVideoAdDidReceiveAd(rewardBasedVideoAd: GADRewardBasedVideoAd!) {
        Debug.print("AdMob reward video ad  did receive ad")
    }
    
    func rewardBasedVideoAdDidStartPlaying(rewardBasedVideoAd: GADRewardBasedVideoAd!) {
        Debug.print("AdMob reward video ad  did start playing")
    }
    
    func rewardBasedVideoAdWillLeaveApplication(rewardBasedVideoAd: GADRewardBasedVideoAd!) {
        Debug.print("AdMob reward video ad will leave application")
        delegate?.adMobAdClicked()
    }
    
    func rewardBasedVideoAd(rewardBasedVideoAd: GADRewardBasedVideoAd!, didFailToLoadWithError error: NSError!) {
        Debug.print("AdMob reward video ad did fail to load")
        Debug.print(error.localizedDescription)
        errorDelegate?.adMobInterFail()
        // try reloading new ad and see if it causes issues
    }
    
    func rewardBasedVideoAd(rewardBasedVideoAd: GADRewardBasedVideoAd!, didRewardUserWithReward reward: GADAdReward!) {
        Debug.print("AdMob reward video ad did reward user")
        delegate?.adMobDidRewardUser(rewardAmount: Int(reward.amount))
    }
}