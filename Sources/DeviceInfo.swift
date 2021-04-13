import Foundation
import UIKit

extension UIUserInterfaceIdiom {
    var name: String {
        switch self {
        case .unspecified:
            return "unspecified"
        case .phone:
            return "phone"
        case .pad:
            return "pad"
        case .tv:
            return "tv"
        case .carPlay:
            return "carPlay"
        case .mac:
            return "mac"
        default:
            return "unknown"
        }
    }
}

struct DeviceInfoRoot: Encodable {
    var ios: DeviceInfoIOS
}

struct DeviceInfoIOS: Encodable {
    var uname: DeviceInfoUname
    var uiDevice: DeviceInfoUIDevice
    var nsProcessInfo: DeviceInfoNSProcessInfo
    var nsBundle: DeviceInfoNSBundle

    enum CodingKeys: String, CodingKey {
        case uname
        case uiDevice = "UIDevice"
        case nsProcessInfo = "NSProcessInfo"
        case nsBundle = "NSBundle"
    }
}

struct DeviceInfoUname: Encodable {
    var machine: String
    var nodename: String
    var release: String
    var sysname: String
    var version: String
}

struct DeviceInfoUIDevice: Encodable {
    var name: String
    var systemName: String
    var systemVersion: String
    var model: String
    var userInterfaceIdiom: String
}

struct DeviceInfoNSProcessInfo: Encodable {
    var isMacCatalystApp: Bool
    var isiOSAppOnMac: Bool
}

struct DeviceInfoNSBundle: Encodable {
    var cfBundleIdentifier: String
    var cfBundleDisplayName: String
    var cfBundleExecutable: String
    var cfBundleShortVersionString: String
    var cfBundleVersion: String

    enum CodingKeys: String, CodingKey {
        case cfBundleIdentifier = "CFBundleIdentifier"
        case cfBundleDisplayName = "CFBundleDisplayName"
        case cfBundleExecutable = "CFBundleExecutable"
        case cfBundleShortVersionString = "CFBundleShortVersionString"
        case cfBundleVersion = "CFBundleVersion"
    }
}

func getDeviceInfo() -> DeviceInfoRoot {
    // uname
    var systemInfo = utsname()
    uname(&systemInfo)

    let machine = withUnsafePointer(to: &systemInfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            ptr in String(validatingUTF8: ptr)
        }
    }!
    let nodename = withUnsafePointer(to: &systemInfo.nodename) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            ptr in String(validatingUTF8: ptr)
        }
    }!
    let release = withUnsafePointer(to: &systemInfo.release) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            ptr in String(validatingUTF8: ptr)
        }
    }!
    let sysname = withUnsafePointer(to: &systemInfo.sysname) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            ptr in String(validatingUTF8: ptr)
        }
    }!
    let version = withUnsafePointer(to: &systemInfo.version) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            ptr in String(validatingUTF8: ptr)
        }
    }!

    // UIDevice
    let currentDevice = UIDevice.current

    // NSBundle
    let infoDict = Bundle.main.infoDictionary!
    let cfBundleIdentifier = infoDict["CFBundleIdentifier"] as! String
    let cfBundleDisplayName = infoDict["CFBundleDisplayName"] as! String
    let cfBundleExecutable = infoDict["CFBundleExecutable"] as! String
    let cfBundleShortVersionString = infoDict["CFBundleShortVersionString"] as! String
    let cfBundleVersion = infoDict["CFBundleVersion"] as! String

    var root = DeviceInfoRoot(
        ios: DeviceInfoIOS(
            uname: DeviceInfoUname(
                machine: machine,
                nodename: nodename,
                release: release,
                sysname: sysname,
                version: version
            ),
            uiDevice: DeviceInfoUIDevice(
                name: currentDevice.name,
                systemName: currentDevice.systemName,
                systemVersion: currentDevice.systemVersion,
                model: currentDevice.model,
                userInterfaceIdiom: currentDevice.userInterfaceIdiom.name
            ),
            nsProcessInfo: DeviceInfoNSProcessInfo(
                isMacCatalystApp: false,
                isiOSAppOnMac: false
            ),
            nsBundle: DeviceInfoNSBundle(
                cfBundleIdentifier: cfBundleIdentifier,
                cfBundleDisplayName: cfBundleDisplayName,
                cfBundleExecutable: cfBundleExecutable,
                cfBundleShortVersionString: cfBundleShortVersionString,
                cfBundleVersion: cfBundleVersion
            )
        )
    )

    // NSProcessInfo
    if #available(iOS 13.0, *) {
        let processInfo = ProcessInfo.processInfo
        root.ios.nsProcessInfo.isMacCatalystApp = processInfo.isMacCatalystApp
        if #available(iOS 14.0, *) {
            root.ios.nsProcessInfo.isiOSAppOnMac = processInfo.isiOSAppOnMac
        }
    }

    return root
}
