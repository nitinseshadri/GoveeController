//
//  ViewController.swift
//  GoveeController
//
//  Created by Nitin Seshadri on 2/13/22.
//

import Cocoa
import CoreBluetooth

class ViewController: NSViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // MARK: View Actions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        NSApp.setActivationPolicy(.accessory)
        
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue(label: "bt_queue"))
    }
    
    // MARK: IBOutlets
    
    @IBOutlet weak var connectionStatusLabel: NSTextField!
    
    // MARK: IBActions
    
    @IBAction func turnOn(_ sender: Any) {
        guard connectedPeripheral != nil else { return }
        
        write(Data(onCommand), characteristic: storedCharacteristic, withResponse: false)
        
        print("User turned peripheral ON")
    }
    
    
    @IBAction func turnOff(_ sender: Any) {
        guard connectedPeripheral != nil else { return }
        
        write(Data(offCommand), characteristic: storedCharacteristic, withResponse: false)
        
        print("User turned peripheral OFF")
    }
    
    // MARK: Bluetooth
    
    private var centralManager: CBCentralManager!
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScan()
            break
        case .poweredOff:
            // Alert user to turn on Bluetooth
            print("Bluetooth is powered off. Please turn Bluetooth on.")
            break
        case .resetting:
            // Wait for next state update and consider logging interruption of Bluetooth service
            break
        case .unauthorized:
            // Alert user to enable Bluetooth permission in app Settings
            print("Bluetooth permissions are not enabled. Please go to System Preferences to grant access.")
            break
        case .unsupported:
            // Alert user their device does not support Bluetooth and app will not work as expected
            print("Bluetooth is not supported on this device.")
            break
        case .unknown:
            // Wait for next state update
            break
        @unknown default:
            break
        }
    }
    
    // MARK: Peripheral Properties

    let peripheralNameMatch = "H6125"
    let serviceUUID = CBUUID(string: "00010203-0405-0607-0809-0a0b0c0d1910")
    let characteristicUUID = CBUUID(string: "00010203-0405-0607-0809-0a0b0c0d2b11")
    
    // MARK: Peripheral Commands
    
    let onCommand: [UInt8] = [0x33, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x33]
    let offCommand: [UInt8] = [0x33, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x32]
    let keepAliveCommand: [UInt8] = [0xAA, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xAB]
    
    // MARK: Discover Peripherals
    
    var connectedPeripheral: CBPeripheral!
    var storedCharacteristic: CBCharacteristic!

    func startScan() {
        print("Starting Bluetooth scan.")
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        DispatchQueue.main.async { [unowned self] in
            connectionStatusLabel.stringValue = "Not connected"
        }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let peripheralName = peripheral.name {
            if peripheralName.contains(peripheralNameMatch) {
                print("Discovered peripheral: \(peripheralName) (matches criteria). Stopping scan.")
                
                centralManager.stopScan()
                
                print("Will connect to peripheral \(peripheralName).")
                self.connectedPeripheral = peripheral
                centralManager.connect(connectedPeripheral, options: nil)
            } else {
                print("Discovered peripheral: \(peripheralName)")
            }
        }
    }
    
    // MARK: Connecting

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Successfully connected. Store reference to peripheral if not already done.
        self.connectedPeripheral = peripheral
        peripheral.delegate = self
        
        if let peripheralName = peripheral.name {
            print("Connected to peripheral \(peripheralName)")
        } else {
            print("Connected to peripheral")
        }
        
        peripheral.discoverServices([serviceUUID])
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print(error)
        }
        
        print("There was a problem connecting to the peripheral. Restarting scan.")

        startScan()
    }
    
    // MARK: Disconnecting

    func disconnect(peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print(error)
        }
        
        print("Disconnected from the peripheral. Restarting scan.")
        
        startScan()
    }
    
    // MARK: Discover Services

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print(error)
            
            print("There was a problem discovering the peripheral's services. Disconnecting and restarting scan.")
            
            disconnect(peripheral: peripheral)
            return
        }
        
        guard let services = peripheral.services else {
            print("No services were found that matched the given criteria. Disconnecting and restarting scan.")
            
            disconnect(peripheral: peripheral)
            return
        }
        
        print("Found services matching the given criteria. Will find characteristics.")
        
        for service in services {
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }
    
    // MARK: Discover Characteristics
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            print("No characteristics were found that matched the given criteria. Disconnecting and restarting scan.")
            
            disconnect(peripheral: peripheral)
            return
        }
        
        print("Found characteristics matching the given criteria.")
        
        // Consider storing important characteristics internally for easy access and equivalency checks later.
        // From here, can read/write to characteristics or subscribe to notifications as desired.
        for characteristic in characteristics {
            storedCharacteristic = characteristic
        }
        
        startSendingKeepAliveCommands()
        
        DispatchQueue.main.async { [unowned self] in
            connectionStatusLabel.stringValue = "Connected"
        }
    }
    
    // MARK: R/W Characteristic
    
    func subscribeToNotifications(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        peripheral.setNotifyValue(true, for: characteristic)
    }
    
    func readValue(characteristic: CBCharacteristic) {
        self.connectedPeripheral?.readValue(for: characteristic)
    }

    func write(_ value: Data, characteristic: CBCharacteristic, withResponse: Bool) {
        if (withResponse) {
            self.connectedPeripheral?.writeValue(value, for: characteristic, type: .withResponse)
        } else {
            if connectedPeripheral?.canSendWriteWithoutResponse == true {
                self.connectedPeripheral?.writeValue(value, for: characteristic, type: .withoutResponse)
            }
        }
    }
    
    func startSendingKeepAliveCommands() {
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            while connectedPeripheral.state == .connected {
                write(Data(keepAliveCommand), characteristic: storedCharacteristic, withResponse: false)
                print("Sent keep-alive command to peripheral")
                sleep(1)
            }
        }
    }

}

