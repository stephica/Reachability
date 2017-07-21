//
//  ViewController.swift
//  Reachability
//
//  Created by 萧宇 on 21/07/2017.
//  Copyright © 2017 IDanielLam. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    var reachability: Reachability!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        do {
            self.reachability = try Reachability()
        } catch ReachabilityInitError.FailedToCreateWithAddress {
            print("Init with address failed")
        } catch ReachabilityInitError.failedToCreateWithHostname {
            print("Init with hostname failed")
        } catch {
            print("Unknown error")
        }
        
        do {
            try self.reachability.startNotifier()
            NotificationCenter.default.addObserver(self, selector: #selector(networkStatusChanged(notification:)), name: reachabilityChangedNotification, object: nil)
        } catch ReachabilityNotifierError.UnableToSetCallback {
            print("Notification set callback failed")
        } catch ReachabilityNotifierError.UnableToSetDispatchQueue {
            print("Notification set dispatch queue failed")
        } catch {
            print("Unknown error")
        }
    }
    
    func networkStatusChanged(notification: Notification) {
        let status = notification.object as! NetworkStatus
        switch status {
        case .notReachable:
            print(status)
            // Do something here
        case .unknown:
            print(status)
            // Do something here
        case .wifi:
            print(status)
            // Do something here
        case .wwan2G:
            print(status)
            // Do something here
        case .wwan3G:
            print(status)
            // Do something here
        case .wwan4G:
            print(status)
            // Do something here
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

