//
//  BleManager.swift
//  bluefruitconnect
//
//  Created by Antonio García on 23/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth

class BleManager : NSObject, CBCentralManagerDelegate {
    
    // Configuration
    static let kIsUndiscoverPeripheralsEnabled = true                   // If true, the BleManager will check periodically if devices are no longer in range
    static let kUndiscoverCheckPeriod = 1.0                             // in seconds
    static let kUndiscoverPeripheralConsideredOutOfRangeTime = 30.0      // in seconds
    
    // Notifications
    enum BleNotifications : String {
        case DidUpdateBleState = "didUpdateBleState"
        case DidStartScanning = "didStartScanning"
        case DidStopScanning = "didStopScanning"
        case DidDiscoverPeripheral = "didDiscoverPeripheral"
        case DidUnDiscoverPeripheral = "didUnDiscoverPeripheral"
        case WillConnectToPeripheral = "willConnectToPeripheral"
        case DidConnectToPeripheral = "didConnectToPeripheral"
        case WillDisconnectFromPeripheral = "willDisconnectFromPeripheral"
        case DidDisconnectFromPeripheral = "didDisconnectFromPeripheral"
    }
    
    // Main
    static let sharedInstance = BleManager()
    var centralManager : CBCentralManager?
    
    // Scanning
    var isScanning = false
    var blePeripheralsFound = [String : BlePeripheral]()
    var blePeripheralConnecting : BlePeripheral?
    var blePeripheralConnected : BlePeripheral?             // last peripheral connected (TODO: take into account that multiple peripherals can can be connected at the same time
    var undiscoverTimer : NSTimer?

    //
    override init() {
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func restoreCentralManager() {
        // Restore central manager delegate if was changed
        centralManager?.delegate = self
    }
    
    func startScan() {
        DLog("startScan");
        
        isScanning = true
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidStartScanning.rawValue, object: nil)
        if (BleManager.kIsUndiscoverPeripheralsEnabled) {
             undiscoverTimer = NSTimer.scheduledTimerWithTimeInterval(BleManager.kUndiscoverCheckPeriod, target: self, selector:"checkUndiscoveredPeripherals", userInfo: nil, repeats: true)
        }
        
        let allowDuplicateKeys = BleManager.kIsUndiscoverPeripheralsEnabled
        let scanOptions = allowDuplicateKeys ? [CBCentralManagerScanOptionAllowDuplicatesKey : true] as [String: AnyObject]? : nil
        centralManager?.scanForPeripheralsWithServices(nil, options: scanOptions)
        
    }
    
    func stopScan() {
        DLog("stopScan");
        
        centralManager?.stopScan()
        isScanning = false
        if (BleManager.kIsUndiscoverPeripheralsEnabled) {
            undiscoverTimer?.invalidate()
            undiscoverTimer = nil
        }
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidStopScanning.rawValue, object: nil)
    }
   
    
    func connect(blePeripheral : BlePeripheral) {
        blePeripheralConnecting = blePeripheral
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.WillConnectToPeripheral.rawValue, object: blePeripheral.peripheral.identifier.UUIDString)

        centralManager?.connectPeripheral(blePeripheral.peripheral, options: nil)
    }
    
    func disconnect(blePeripheral : BlePeripheral) {

        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.WillDisconnectFromPeripheral.rawValue, object: blePeripheral.peripheral.identifier.UUIDString)
        centralManager?.cancelPeripheralConnection(blePeripheral.peripheral)
    }
    
    func discover(blePeripheral : BlePeripheral, serviceUUIDs: [CBUUID]?) {
        blePeripheral.peripheral.discoverServices(serviceUUIDs)
    }
    
    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(central: CBCentralManager) {
        DLog("centralManagerDidUpdateState \(central.state.rawValue)")
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidUpdateBleState.rawValue, object: central.state.rawValue)
        
        if (central.state != .PoweredOn) {
            if let blePeripheralConnected = blePeripheralConnected{
                DLog("Bluetooth is not powered on. Disconnect connected peripheral")
                blePeripheralConnecting = nil
                disconnect(blePeripheralConnected)
            }
            
            isScanning = false
        }
    }
    
    func checkUndiscoveredPeripherals() {
        let currentTime = CFAbsoluteTimeGetCurrent()
        for (identifier, blePeripheral) in blePeripheralsFound {
            let elapsedTime = currentTime - blePeripheral.lastSeenTime
            if elapsedTime > BleManager.kUndiscoverPeripheralConsideredOutOfRangeTime {
                DLog("undiscovered peripheral: \(blePeripheral.name)")
                blePeripheralsFound.removeValueForKey(identifier)
                 NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidUnDiscoverPeripheral.rawValue, object: identifier);
            }

//            let elapsedFormatted = String(format:"%.2f", elapsedTime)
//            DLog("peripheral \(blePeripheral.name): elapsed \( elapsedFormatted )")

        }
        
        
       // DLog("--")
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral,  advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        let identifierString = peripheral.identifier.UUIDString
        //DLog("didDiscoverPeripheral \(peripheral.name)")
        if var existingPeripheral = blePeripheralsFound[identifierString] {
            // Existing peripheral. Update advertisement data because each time is discovered the advertisement data could miss some of the keys (sometimes a sevice is there, and other times has dissapeared)

            existingPeripheral.rssi = RSSI.integerValue
            existingPeripheral.lastSeenTime = CFAbsoluteTimeGetCurrent()
            for (key, value) in advertisementData {
                existingPeripheral.advertisementData.updateValue(value, forKey: key);
            }
            blePeripheralsFound[identifierString] = existingPeripheral
           
        }
        else {      // New peripheral found
            let blePeripheral = BlePeripheral(peripheral: peripheral, advertisementData: advertisementData, RSSI: RSSI.integerValue)
            blePeripheralsFound[identifierString] = blePeripheral
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidDiscoverPeripheral.rawValue, object: identifierString);
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        DLog("didConnectPeripheral \(peripheral.name)")
        
        blePeripheralConnecting = nil
        let identifier = peripheral.identifier.UUIDString;
        blePeripheralConnected = blePeripheralsFound[identifier]
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidConnectToPeripheral.rawValue, object: identifier)
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        DLog("didDisconnectPeripheral \(peripheral.name)")

        peripheral.delegate = nil
        if peripheral.identifier == blePeripheralConnected?.peripheral.identifier {
            self.blePeripheralConnected = nil
        }

        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidDisconnectFromPeripheral.rawValue, object: peripheral.identifier.UUIDString)
    }

    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        DLog("didFailToConnectPeripheral \(peripheral.name)")
     
        blePeripheralConnecting = nil
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidDisconnectFromPeripheral.rawValue, object: peripheral.identifier.UUIDString)
    }
    
    // MARK: - Utils
    func blePeripheralFoundAlphabeticKeys() -> [String] {
        // Sort blePeripheralsFound keys alphabetically and return them as an array
        let sortedKeys = Array(blePeripheralsFound.keys).sort({[unowned self] in self.blePeripheralsFound[$0]!.name < self.blePeripheralsFound[$1]!.name})
        return sortedKeys
    }
    
    
   
}