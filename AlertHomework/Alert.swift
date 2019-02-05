//
//  Alert.swift
//  AlertHomework
//
//  Created by Timofey Kuzmin on 05/02/2019.
//  Copyright © 2019 In4mo. All rights reserved.
//

import UIKit

@objcMembers class Alert: UIAlertController {
    
    @objc enum DisplayingBehavior: Int {
        
        /// Presenting: Show alert if no presented yet. Otherwise, dismiss the presented and show itself.
        ///
        /// Dismissing: Dismiss the presented and show the next from queue if exists.
        case `default`
        
        /// Dismiss the presented alert if it shown and clear queue.
        case discardAll
        
        /// Presenting: Show alert if no presented yet. Otherwise, add to the end of queue for showing after all alerts.
        ///
        /// Dismissing: Put presented alert in queue and dismiss it without presenting new. Call `Alert.presentNext()` to present a waiting alert from queue.
        case passive
    }
    
    @discardableResult
    static func make(title: String? = nil, message: String?) -> Alert {
        return Alert(title: title, message: message, preferredStyle: .alert)
    }
    
    func show(animated: Bool, behavior: DisplayingBehavior = .default, completion: (() -> ())? = nil) {
        guard let host = Alert.topViewController else { return }
        if isPresented || isAlreadyInQueue {
            return
        }
        switch behavior {
        case .default:
            if let presentedAlert = host as? Alert {
                presentedAlert.addToQueue(animated: true)
                presentedAlert.dismiss(animated: false) {
                    Alert.topViewController?.present(self, animated: animated, completion: completion)
                }
                return
            }
        case .discardAll:
            Alert.queue.removeAll()
            if let presentedAlert = host as? Alert {
                presentedAlert.dismiss(animated: animated, behavior: .passive) {
                    Alert.topViewController?.present(self, animated: animated, completion: completion)
                }
                return
            }
        case .passive:
            if host is Alert {
                addToQueue(animated: animated)
                completion?()
                return
            }
        }
        host.present(self, animated: animated, completion: completion)
    }
    
    static func showNext(animated: Bool, completion: (() -> ())? = nil) {
        guard let top = Alert.topViewController else { return }
        if let presentedAlert = top as? Alert {
            // Popping of next alert will perform in `dismiss()`
            presentedAlert.dismiss(animated: false, completion: completion)
            return
        }
        guard let alertItem = Alert.queue.popLast() else {
            completion?()
            return
        }
        top.present(alertItem.alert, animated: animated) {
            alertItem.completion?()
            completion?()
        }
    }
    
    /// Just adds alert in queue without presentation or dismission.
    func postponePresentation(animated: Bool, completion: (() -> ())? = nil) {
        if !isPresented {
            addToQueue(animated: animated, completion: completion)
        }
    }
    
    override func dismiss(animated: Bool, completion: (() -> ())? = nil) {
        dismiss(animated: animated, behavior: .default, completion: completion)
    }
    
    func dismiss(animated: Bool, behavior: DisplayingBehavior, completion: (() -> ())? = nil) {
        switch behavior {
        case .default:
            break
        case .discardAll:
            Alert.queue.removeAll()
        case .passive:
            addToQueue(animated: true)
        }
        
        if !isPresented {
            // Current (self) alert is not presented
            completion?()
            return
        }
        
        switch behavior {
        case .passive:
            super.dismiss(animated: animated, completion: completion)
        case .default, .discardAll:
            guard let alertItem = Alert.queue.popLast() else {
                super.dismiss(animated: animated, completion: completion)
                return
            }
            super.dismiss(animated: animated) {
                alertItem.alert.show(animated: alertItem.animated) {
                    alertItem.completion?()
                    completion?()
                }
            }
        }
    }
    
    static func dismissTop(animated: Bool, behavior: DisplayingBehavior = .default, completion: (() -> ())? = nil) {
        if let top = Alert.topViewController as? Alert {
            top.dismiss(animated: animated, behavior: behavior, completion: completion)
        } else {
            completion?()
        }
    }
    
    static var hasPresentedInstance: Bool {
        return Alert.topViewController is Alert
    }
    
    var isPresented: Bool {
        if presentingViewController != nil {
            return true
        }
        // Check top presented Alert is equal to self to prevent show similar alert
        if let presentedAlert = Alert.topViewController as? Alert,
            isEqual(presentedAlert) {
            return true
        }
        return false
    }
    
    var isAlreadyInQueue: Bool {
        return Alert.queue.contains { isEqual($0.alert) }
    }
    
    // MARK: - Private stuff
    
    private func addToQueue(animated: Bool, completion: (() -> ())? = nil) {
        if isAlreadyInQueue {
            return
        }
        let item = QueueItem(alert: self, animated: animated, completion: completion)
        Alert.queue.append(item)
    }
    
    private func isEqual(_ other: Alert) -> Bool {
        return title == other.title &&
            message == other.message &&
            other.actions.count == actions.count
    }
    
    fileprivate struct QueueItem {
        let alert: Alert
        let animated: Bool
        let completion: (() -> ())?
    }
    
    private static var queue: [QueueItem] = []
    
    private static var topViewController: UIViewController? {
        guard let window = UIApplication.shared.keyWindow,
            let host = window.topmostViewController else {
                // TODO: replace with logger
                print("WARNING! No top view controller to present UIAlertController.")
                return nil
        }
        return host
    }
    
}

// MARK: - Actions for alerts

extension Alert {
    
    // TODO: remove magic strings
    func addCancel(title: String = "Cancel", handler: (() -> Void)? = nil) {
        addAction(title: title, style: .cancel) { action in
            handler?()
        }
    }
    
    func addSettings() {
        addAction(title: "Settings", style: .`default`) { action in
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                return
            }
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    func addRetry(handler: @escaping () -> Void) {
        addAction(title: "Retry", style: .default) { action in
            handler()
        }
    }
    
    @discardableResult
    func addAction(title: String?, style: UIAlertAction.Style, handler: ((UIAlertAction) -> ())? = nil) -> UIAlertAction {
        let action = UIAlertAction(title: title, style: style) { inAction in
            handler?(inAction)
            if let alertItem = Alert.queue.popLast() {
                alertItem.alert.show(animated: alertItem.animated, completion: alertItem.completion)
            }
        }
        addAction(action)
        return action
    }
    
}

// MARK: - Just some extensions for this assignment, no rocket science here

private extension UIWindow {
    
    var topmostViewController: UIViewController? {
        guard let root = rootViewController else {
            return nil
        }
        return root.topmostViewController
    }
}

private extension UIViewController {
    
    /// Search of topmost view controller from current (self) to top
    var topmostViewController: UIViewController {
        var stack = [self]
        UIViewController.traceToTop(withViewControllers: &stack, navigationDeep: 0)
        return stack.last!
    }
    
    /// - returns: Navigation deep
    @discardableResult
    private static func traceToTop(withViewControllers stack: inout [UIViewController], navigationDeep: Int) -> Int {
        let top = stack.last
        var navigationDeep = navigationDeep
        if let tabVC = top as? UITabBarController,
            let selectedTabVC = tabVC.selectedViewController {
            stack.append(selectedTabVC)
        } else if let presentedVC = top?.presentedViewController {
            stack.append(presentedVC)
        } else if let navVC = top as? UINavigationController {
            stack += navVC.viewControllers
            navigationDeep += max(navVC.viewControllers.count, 1) - 1
        } else if let children = top?.children,
            !children.isEmpty {
            stack += children
        } else {
            return navigationDeep
        }
        return traceToTop(withViewControllers: &stack, navigationDeep: navigationDeep)
    }
    
}

