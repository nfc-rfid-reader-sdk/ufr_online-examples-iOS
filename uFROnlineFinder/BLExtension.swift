//
//  BLExtenstion.swift
//  uFROnlineFinder
//
//  Created by D-Logic on 9/20/19.
//  Copyright © 2019 Digital Logic. All rights reserved.
//

import Foundation
import CoreBluetooth

extension MainViewController: CBCentralManagerDelegate
{
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
        case .unsupported:
            print("central.state is .unsupported")
        case .unauthorized:
            print("central.state is .unauthorized")
        case .poweredOff:
            print("central.state is .poweredOff")
        case .poweredOn:
            print("central.state is .poweredOn")
        @unknown default:
            print("central.state is ???")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if self.bleManual == false {
            if (peripheral.name?.contains("_BLE") ?? false) && (peripheral.name?.contains("ON") ?? false){
                print(peripheral.name!)
                
                uFROnlinePeripheral = peripheral
                foundPeripherals.append(peripheral)
                AddresPickerData.append(peripheral.name!)
                uFROnlinePeripheral.delegate = self
            }
        } else {
           
            if (peripheral.name == txtManualAddress.text) {
                self.alert.dismiss(animated: false, completion: {
                    
                    self.uFROnlinePeripheral = peripheral
                    self.uFROnlinePeripheral.delegate = self
                    central.stopScan()
                    self.bleDone = true
                    return
                })
                
            } else {
                //print("did not find it manually")
                self.bleDone = false
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        //print("-----------------------------")
        print("Connected: " + peripheral.name!)
        //print("-----------------------------")

        peripheral.discoverServices(nil)
        connectedReader = peripheral
        
        
        self.btnConnect.setBackgroundImage(UIImage(named: "connected_1"), for: UIControl.State.normal)
        self.btnConnect.isEnabled = true
        
        self.bleConnected = true
        
        self.alert.dismiss(animated: false, completion: {
            self.bleDone = true
        })
        
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        //print(error)
        self.alert.dismiss(animated: false, completion: nil)
        
        let notice = UIAlertController(title: "Failed to connect!" , message: error as! String, preferredStyle: .alert)
        
        self.present(notice, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            notice.dismiss(animated: false, completion: nil)
        }
        
        self.bleConnected = false
        self.btnConnect.isUserInteractionEnabled = true
        self.btnConnect.setBackgroundImage(UIImage(named: "connect"), for: UIControl.State.normal)
        
        self.btnConnect.isEnabled = true
        
        return
        
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedReader = nil
        print("Disconnected: " + peripheral.name!)
        
        self.bleConnected = false
        self.btnConnect.isUserInteractionEnabled = true
        self.btnConnect.setBackgroundImage(UIImage(named: "connect"), for: UIControl.State.normal)
       
        self.btnConnect.isEnabled = true
    }
}

extension MainViewController: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {return}
        for service in services {
            print(service)
            print(peripheral.discoverCharacteristics(nil, for: service))

        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            print(characteristic)
        }
        
        uFRCharacteristic = characteristics
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        self.bleResp = ""
        //print(characteristic.value!.hexa)
        self.bleResp = characteristic.value!.hexa
        self.bleDone = true
        
    }
    
}
