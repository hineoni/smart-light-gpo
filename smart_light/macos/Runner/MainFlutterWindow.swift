import Cocoa
import FlutterMacOS
import ESPProvisionMac

class MainFlutterWindow: NSWindow {
  private var bleProvisioner: MacBleProvisioner?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "smart_light/macos_ble_provisioning",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "provisionWifi",
            let args = call.arguments as? [String: String],
            let name = args["deviceName"],
            let pop = args["proofOfPossession"],
            let ssid = args["ssid"],
            let passphrase = args["passphrase"] else {
        result(FlutterMethodNotImplemented)
        return
      }
      let provisioner = MacBleProvisioner()
      self?.bleProvisioner = provisioner
      provisioner.provision(name: name, pop: pop, ssid: ssid, passphrase: passphrase) { success in
        result(success)
        self?.bleProvisioner = nil
      }
    }

    super.awakeFromNib()
  }
}

private class MacBleProvisioner {
  private var device: ESPDevice?
  private var finished = false

  func provision(name: String, pop: String, ssid: String, passphrase: String,
                 completion: @escaping (Bool) -> Void) {
    func finish(_ success: Bool) {
      guard !finished else { return }
      finished = true
      completion(success)
      device?.disconnect()
      device = nil
    }

    ESPProvisionManager.shared.createESPDevice(
      deviceName: name, transport: .ble, security: .secure,
      proofOfPossession: pop) { [self] found, error in
      guard error == nil, let found = found else {
        NSLog("SmartLight BLE: device discovery failed: %@", error?.description ?? "unknown error")
        finish(false)
        return
      }
      device = found
      found.connect { status in
        switch status {
        case .connected:
          found.provision(ssid: ssid, passPhrase: passphrase) { status in
            switch status {
            case .success: finish(true)
            case .failure(let error):
              NSLog("SmartLight BLE: provisioning failed: %@", error.description)
              finish(false)
            case .configApplied: break
            }
          }
        case .failedToConnect(let error):
          NSLog("SmartLight BLE: connection failed: %@", error.description)
          finish(false)
        case .disconnected:
          NSLog("SmartLight BLE: device disconnected")
          finish(false)
        }
      }
    }
  }
}
