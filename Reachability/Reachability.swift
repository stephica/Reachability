//
//  Reachability.swift
//  Reachability
//
//  Created by 萧宇 on 21/07/2017.
//  Copyright © 2017 IDanielLam. All rights reserved.
//

import UIKit
import CoreTelephony
import SystemConfiguration

public let reachabilityChangedNotification = Notification.Name(rawValue: "ReachabilityChangedNotification")

public enum NetworkStatus: CustomStringConvertible {
    case notReachable
    case unknown
    case wifi
    case wwan2G
    case wwan3G
    case wwan4G
    
    public var description: String {
        switch self {
        case .notReachable:
            return "No connection"
        case .unknown:
            return "Unknown connection"
        case .wwan2G:
            return "2G cellular network"
        case .wwan3G:
            return "3G cellular network"
        case .wwan4G:
            return "4G cellular network"
        case .wifi:
            return "WiFi network"
        }
    }
}

public enum ReachabilityInitError: Error {
    case FailedToCreateWithAddress(sockaddr)
    case failedToCreateWithHostname(String)
}

public enum ReachabilityNotifierError: Error {
    case UnableToSetCallback
    case UnableToSetDispatchQueue
}

fileprivate func callback(reachability: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer?) {
    guard let info = info else { return }
    
    let reachability = Unmanaged<Reachability>.fromOpaque(info).takeUnretainedValue()
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: reachabilityChangedNotification, object:reachability.currentReachabilityStatus)
    }
}

public class Reachability {
    
    fileprivate var reachabilityRef: SCNetworkReachability?
    
    required public init(reachabilityRef: SCNetworkReachability) {
        self.reachabilityRef = reachabilityRef
    }
    
    public convenience init(hostname: String) throws {
        guard let ref = SCNetworkReachabilityCreateWithName(nil, hostname) else { throw ReachabilityInitError.failedToCreateWithHostname(hostname) }
        self.init(reachabilityRef: ref)
    }
    
    public convenience init(address: inout sockaddr) throws {
        guard let ref: SCNetworkReachability = withUnsafePointer(to: &address, {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
        }) else { throw ReachabilityInitError.FailedToCreateWithAddress(address) }
        
        self.init(reachabilityRef: ref)
    }
    
    public convenience init() throws {
        var zeroAddress = sockaddr()
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)
        do {
            try self.init(address: &zeroAddress)
        } catch {
            throw error
        }
    }
    
    deinit {
        stopNotifier()
        reachabilityRef = nil
    }
    
    public var currentReachabilityStatus: NetworkStatus {
        var status: NetworkStatus = .notReachable
        
        var flags = SCNetworkReachabilityFlags()
        if SCNetworkReachabilityGetFlags(self.reachabilityRef!, &flags) {
            status = self.networkStatus(for: flags)
        }
        
        return status
    }
    
    fileprivate func networkStatus(`for` flags: SCNetworkReachabilityFlags) -> NetworkStatus {
        guard isReachable else {
            return .notReachable
        }
        
        let isReachableViaWiFi: Bool = {
            guard reachabilityFlags.contains(.reachable) else {
                return false
            }
            
            guard isRunningOnDevice else {
                return true
            }
            
            #if os(iOS)
                return !reachabilityFlags.contains(.isWWAN)
            #else
                return true
            #endif
        }()
        if isReachableViaWiFi {
            return .wifi
        }
        
        if isRunningOnDevice {
            let networkInfo = CTTelephonyNetworkInfo()
            let carrierType = networkInfo.currentRadioAccessTechnology
            switch carrierType{
            case CTRadioAccessTechnologyGPRS?,CTRadioAccessTechnologyEdge?,CTRadioAccessTechnologyCDMA1x?: return .wwan2G
            case CTRadioAccessTechnologyWCDMA?,CTRadioAccessTechnologyHSDPA?,CTRadioAccessTechnologyHSUPA?,CTRadioAccessTechnologyCDMAEVDORev0?,CTRadioAccessTechnologyCDMAEVDORevA?,CTRadioAccessTechnologyCDMAEVDORevB?,CTRadioAccessTechnologyeHRPD?: return .wwan3G
            case CTRadioAccessTechnologyLTE?: return .wwan4G
            default: return .unknown
            }
        }
        
        return .notReachable
    }
    
    fileprivate var isReachable: Bool {
        guard reachabilityFlags.contains(.reachable) else {
            return false
        }
        
        if reachabilityFlags.intersection([.connectionRequired, .transientConnection]) == [.connectionRequired, .transientConnection] {
            return false
        }
        
        return true
    }
    
    fileprivate var reachabilityFlags: SCNetworkReachabilityFlags {
        guard let reachabilityRef = reachabilityRef else { return SCNetworkReachabilityFlags() }
        
        var flags = SCNetworkReachabilityFlags()
        let gotFlags = withUnsafeMutablePointer(to: &flags) {
            SCNetworkReachabilityGetFlags(reachabilityRef, UnsafeMutablePointer($0))
        }
        
        if gotFlags {
            return flags
        } else {
            return SCNetworkReachabilityFlags()
        }
    }
    
    fileprivate var isRunningOnDevice: Bool = {
        #if (arch(i386) || arch(x86_64)) && os(iOS)
            return false
        #else
            return true
        #endif
    }()
    
    fileprivate var isNotifierRunning = false
    fileprivate let reachabilitySerialQueue = DispatchQueue(label: "cn.daniellam.networkKit.reachability")
    
    func startNotifier() throws {
        
        guard let reachabilityRef = reachabilityRef, !isNotifierRunning else { return }
        
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = UnsafeMutableRawPointer(Unmanaged<Reachability>.passUnretained(self).toOpaque())
        if !SCNetworkReachabilitySetCallback(reachabilityRef, callback, &context) {
            stopNotifier()
            throw ReachabilityNotifierError.UnableToSetCallback
        }
        
        if !SCNetworkReachabilitySetDispatchQueue(reachabilityRef, reachabilitySerialQueue) {
            stopNotifier()
            throw ReachabilityNotifierError.UnableToSetDispatchQueue
        }
        
        isNotifierRunning = true
    }
    
    func stopNotifier() {
        defer { isNotifierRunning = false }
        guard let reachabilityRef = reachabilityRef else { return }
        
        SCNetworkReachabilitySetCallback(reachabilityRef, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachabilityRef, nil)
    }
    
}
