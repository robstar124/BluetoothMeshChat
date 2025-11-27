import Flutter
import CoreBluetooth
import UIKit

class BLEAdvertisingPlugin: NsObject, FlutterPlugin {
    static let channelName = "com.meshchat.ble/advertising"

    private var channel: FlutterMethodChannel?
    private var periphereralManager : CBPeripheralManager?
    private var serviceUUID : CBUUID?
    private var deviceId : String?
    private var deviceName : String?
    private var isAdvertising = false

    static func register(with registrar: FlutterPLuginRegistrar) {
        let channel = FlutterMethodChannel(
            name : channelName,
            binaryMessenger : registrar.messenger()
        )

        let instance = BLEAdvertisingPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel : channel)
    }

    func handle(_ call:FlutterMethodChannel, result:@escaping FlutterResult){
        switch call.method {
            case "initialize":
            handleInitialize(call, result : result)

            case "startAdvertising":
            handleStartAdvertising(call, result : result)

            case "stopAdvertising":
            handleStopAdvertising(call, result : result)

            case "isAdvertisingSupported":
            result(true)

            default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleInitialize(_ call : FLutterMethodCall, result : @escaping FlutterResult) {

    }


    private func handleStartAdvertising(_ call : FLutterMethodCall, result : @escaping FlutterResult) {

    }


    private func handleStopAdvertising(_ call : FLutterMethodCall, result : @escaping FlutterResult) {

    }
}