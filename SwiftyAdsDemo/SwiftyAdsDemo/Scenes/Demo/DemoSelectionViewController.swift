import UIKit

final class DemoSelectionViewController: UITableViewController {
    
    // MARK: - Types

    enum Section: CaseIterable {
        case main
        case secondary

        func rows(isRequiredToAskForConsent: Bool) -> [Row] {
            switch self {
            case .main:
                return [
                    .viewController,
                    .viewControllerInsideTabBar,
                    .tabBarController,
                    .spriteKitScene,
                    .nativeAd
                ]
            case .secondary:
                return [
                    isRequiredToAskForConsent ? .updateConsent : nil,
                    .disable
                ].compactMap { $0 }
            }
        }
    }
    
    enum Row {
        case viewController
        case viewControllerInsideTabBar
        case tabBarController
        case spriteKitScene
        case nativeAd

        case updateConsent
        case disable

        var title: String {
            switch self {
            case .viewController:
                return "ViewController"
            case .viewControllerInsideTabBar:
                return "ViewController inside TabBarController"
            case .tabBarController:
                return "TabBarController"
            case .spriteKitScene:
                return "SpriteKit Scene"
            case .nativeAd:
                return "Native Ad"
            case .updateConsent:
                return "Update Consent Status"
            case .disable:
                return "Disable Ads"
            }
        }

        var accessoryType: UITableViewCell.AccessoryType {
            switch self {
            case .updateConsent, .disable:
                return .none
            default:
                return .disclosureIndicator
            }
        }

        var shouldDeselect: Bool {
            switch self {
            case .updateConsent, .disable:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Properties

    private let swiftyAds: SwiftyAdsType
    private let consentConfiguration: SwiftyAdsEnvironment.ConsentConfiguration
    private let sections = Section.allCases
    private let notificationCenter: NotificationCenter = .default
    private var bannerAd: SwiftyAdsBannerType?

    private var isRequiredToAskForConsent: Bool {
        guard !consentConfiguration.isDisabled else { return false }
        return swiftyAds.consentStatus != .notRequired
    }

    // MARK: - Initialization
    
    init(swiftyAds: SwiftyAdsType, consentConfiguration: SwiftyAdsEnvironment.ConsentConfiguration) {
        self.swiftyAds = swiftyAds
        self.consentConfiguration = consentConfiguration
        if #available(iOS 13.0, *) {
            super.init(style: .insetGrouped)
        } else {
            super.init(style: .grouped)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - De-Initialization

    deinit {
        print("Deinit DemoSelectionViewController")
    }
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Swifty Ads Demo"
        tableView.register(BasicCell.self, forCellReuseIdentifier: String(describing: BasicCell.self))
        notificationCenter.addObserver(self, selector: #selector(consentDidChange), name: .adConsentStatusDidChange, object: nil)
        makeBanner()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bannerAd?.show(isLandscape: view.frame.width > view.frame.height)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.bannerAd?.show(isLandscape: size.width > size.height)
        })
    }
    
    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows(isRequiredToAskForConsent: isRequiredToAskForConsent).count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows(isRequiredToAskForConsent: isRequiredToAskForConsent)[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: BasicCell.self), for: indexPath) as! BasicCell
        cell.configure(title: row.title, accessoryType: row.accessoryType)
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = sections[indexPath.section].rows(isRequiredToAskForConsent: isRequiredToAskForConsent)[indexPath.row]
        var viewController: UIViewController?

        if row.shouldDeselect {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        
        switch row {
        case .viewController:
            let plainViewController = PlainViewController(swiftyAds: swiftyAds)
            viewController = plainViewController

        case .viewControllerInsideTabBar:
            viewController = TabBarControllerNoAd(swiftyAds: swiftyAds)
        
        case .tabBarController:
            viewController = TabBarControllerAd(swiftyAds: swiftyAds)
        
        case .spriteKitScene:
            let storyboard = UIStoryboard(name: "GameViewController", bundle: .main)
            let gameViewController = storyboard.instantiateInitialViewController() as! GameViewController
            gameViewController.configure(swiftyAds: swiftyAds)
            viewController = gameViewController

        case .nativeAd:
            viewController = NativeAdViewController(swityAds: swiftyAds)

        case .updateConsent:
            swiftyAds.askForConsent(from: self) { [weak self] result in
                self?.tableView.reloadData()
            }

        case .disable:
            swiftyAds.disable()
            bannerAd?.remove()
            bannerAd = nil
            showDisabledAlert()
        }
        
        guard let validViewController = viewController else { return }
        validViewController.navigationItem.title = row.title
        navigationController?.pushViewController(validViewController, animated: true)
    }
}

// MARK: - Private Methods

private extension DemoSelectionViewController {

    @objc func consentDidChange() {
        if bannerAd == nil {
            makeBanner()
        }
        bannerAd?.show(isLandscape: view.frame.width > view.frame.height)
        tableView.reloadData()
    }

    func makeBanner() {
        bannerAd = swiftyAds.makeBannerAd(
            in: self,
            adUnitIdType: .plist,
            position: .bottom(isUsingSafeArea: true),
            animation: .fade(duration: 1.5),
            onOpen: {
                print("SwiftyAds banner ad did open")
            },
            onClose: {
                print("SwiftyAds banner ad did close")
            },
            onError: { error in
                print("SwiftyAds banner ad error \(error)")
            },
            onWillPresentScreen: {
                print("SwiftyAds banner ad was tapped and is about to present screen")
            },
            onWillDismissScreen: {
                print("SwiftyAds banner ad screen is about to be dismissed")
            },
            onDidDismissScreen: {
                print("SwiftyAds banner did dismiss screen")
            }
        )
    }

    func showDisabledAlert() {
        let alertController = UIAlertController(
            title: "Ads Disabled",
            message: "All ads, except rewarded ads, have been disabled and will no longer display",
            preferredStyle: .alert
        )
        let okAction = UIAlertAction(title: "Ok", style: .default) { _ in }
        alertController.addAction(okAction)
        DispatchQueue.main.async {
            self.present(alertController, animated: true)
        }
    }
}
