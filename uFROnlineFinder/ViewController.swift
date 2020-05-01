//
//  ViewController.swift
//  uFROnlineFinder
//
//  Created by D-Logic on 9/16/19.
//  Copyright © 2019 Digital Logic. All rights reserved.
//

import UIKit
import CoreBluetooth
import SystemConfiguration.CaptiveNetwork
import Starscream


class MainViewController:UIViewController, UIPickerViewDelegate,  UIPickerViewDataSource, UITextFieldDelegate {
    
    @IBOutlet weak var rbHTTP: DLRadioButton!
    @IBOutlet weak var rbTCP: DLRadioButton!
    @IBOutlet weak var rbUDP: DLRadioButton!
    @IBOutlet weak var rbWebSocket: DLRadioButton!
    @IBOutlet weak var rbBLE: DLRadioButton!
    
    //buttons
    @IBOutlet weak var btnScan: UIButton!
    @IBOutlet weak var btnConnect: UIButton!
    @IBOutlet weak var btnUISignal: UIButton!
    @IBOutlet weak var btnGetUID: UIButton!
    @IBOutlet weak var btnSendCommand: UIButton!
    
    // default text fields
    @IBOutlet weak var txtPort: UITextField!
    @IBOutlet weak var txtManualAddress: UITextField!
    @IBOutlet weak var txtCardUID: UITextField!
    @IBOutlet weak var txtCommand: UITextField!
    @IBOutlet weak var txtResponse: UITextView!
    
    //custom text fields with Picker views = ComboBoxes
    @IBOutlet weak var cbAdresses: UITextField!
    @IBOutlet weak var cbUISignalLight: UITextField!
    @IBOutlet weak var cbUISignalSound: UITextField!
    
    //image as header
    @IBOutlet weak var imgHeader: UIImageView!
    
    //main scroll view
    @IBOutlet weak var mainView: UIScrollView!
    
    /*******************************************/
    /*******************************************/
    /*******************************************/
    
    let address_picker = UIPickerView()
    let sound_picker = UIPickerView()
    let light_picker = UIPickerView()
    
    var AddresPickerData = [String](arrayLiteral: "No data yet. Please use [SCAN] first")
    let UISoundPickerData = [String](arrayLiteral: "Short", "Long", "Double short", "Triple short", "Triple melody")
    let UILightPickerData = [String](arrayLiteral: "Long green", "Long red", "Alternation", "Flash")
    
    // BLUETOOTH stuff
    var bleManager: CBCentralManager!
    var uFROnlinePeripheral: CBPeripheral!
    var connectedReader: CBPeripheral!
    var foundPeripherals = [CBPeripheral]()
    var uFRCharacteristic = [CBCharacteristic]()
    var bleResp: String?
    var socketResp: String?
    let alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)
    let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
    
    var bleConnected: Bool = false
    var bleDone: Bool = false
    var bleManual: Bool = false
    
    var webSocketConnected: Bool = false
    var webSocketDone: Bool = false
    var web_socket: WebSocket!
    var wsManual: Bool = false
    
    var old_tag = 0
    
    //////////////////////////////////
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        if #available(iOS 13.0, *) {
            // Always adopt a light interface style.
            overrideUserInterfaceStyle = .light
        }
        rbHTTP.isSelected = true
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        
        mainView.addGestureRecognizer(tap)
        
        address_picker.delegate = self
        cbAdresses.inputView = address_picker
        
        sound_picker.delegate = self
        cbUISignalSound.inputView = sound_picker
        
        light_picker.delegate = self
        cbUISignalLight.inputView = light_picker
        //Picker views to text fields set
        
        bleManager = CBCentralManager(delegate: self, queue: .main)
        bleConnected = false
        
        txtPort.text = "80"
        
        self.btnConnect.setBackgroundImage(UIImage(named: "connected_gray"), for: UIControl.State.normal)
        self.btnConnect.isUserInteractionEnabled = false
    }
    
    // MARK: - Helper functions
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        
        if pickerView == address_picker {
            return AddresPickerData.count
        } else if pickerView == sound_picker {
            return UISoundPickerData.count
        } else if pickerView == light_picker {
            return UILightPickerData.count
        }
        
        return 1
    }
    
    func pickerView( _ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == address_picker {
            return AddresPickerData[row]
        } else if pickerView == sound_picker{
            return UISoundPickerData[row]
        } else if pickerView == light_picker {
            return UILightPickerData[row]
        }
        
        if bleConnected == true {
            bleManager.cancelPeripheralConnection(connectedReader)
        }
        if webSocketConnected == true {
            
            web_socket.disconnect()
        }
        
        return ""
    }
    
    func pickerView( _ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == address_picker {
            if bleConnected == true {
                bleManager.cancelPeripheralConnection(connectedReader)
            }
            if webSocketConnected == true {
                web_socket.disconnect()
            }
                if AddresPickerData.count > 0 {
                    cbAdresses.text = AddresPickerData[row]
                    
                    var manual_address = self.AddresPickerData[row]
                    let index = manual_address.firstIndex(of: " ")
                    
                    if rbBLE.isSelected == false {
                        if cbAdresses.text! == "" {
                            self.txtManualAddress.text = ""
                        } else {
                            manual_address = String(manual_address[manual_address.startIndex..<index!])
                            self.txtManualAddress.text = manual_address
                        }
                    }
                    else {
                        self.txtManualAddress.text = AddresPickerData[row]
                        let selected_row = address_picker.selectedRow(inComponent: 0)
                        uFROnlinePeripheral = foundPeripherals[selected_row]
                    }
                }
            } else if pickerView == sound_picker {
                cbUISignalSound.text = UISoundPickerData[row]
            } else if pickerView == light_picker {
                cbUISignalLight.text = UILightPickerData[row]
            }
        
        self.view.endEditing(true)
    }
    
    //used for dismissing keyboard input when tapping anywhere
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        switch textField.tag {
        case 0...5:
            //print("Do nothing")
            break
        default:
            mainView.setContentOffset(CGPoint(x: 0, y: 130), animated: true)
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        mainView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    ////////////////////////////////////////////////////////////////
    // MARK: - Reader functions
    ////////////////////////////////////////////////////////////////
    
    @IBAction func ConnectionSelection(_ sender: UIButton) {
        
        if bleConnected == true {
            
            bleManager.cancelPeripheralConnection(connectedReader)
            
        }
        if webSocketConnected == true {
            web_socket.disconnect()
        }
        
        let current_tag = sender.tag
        print(current_tag)
        
        if ((0...3).contains(current_tag)) == false{
            txtManualAddress.text = ""
            cbAdresses.text = ""
            AddresPickerData = [String]() // clear current data about readers found
        } else if old_tag == 4 {
            txtManualAddress.text = ""
            cbAdresses.text = ""
            AddresPickerData = [String]() // clear current data about readers found
        }
        
        if current_tag == 0 {
            txtPort.text = "80"
        } else if (1...3).contains(current_tag) {
            txtPort.text = "8881"
        } else {
            txtPort.text = ""
        }
        
        if (current_tag == 3) || (current_tag == 4) {
            if self.btnConnect.isUserInteractionEnabled == false {
                self.btnConnect.isUserInteractionEnabled = true
                self.btnConnect.setBackgroundImage(UIImage(named: "connect"), for: UIControl.State.normal)
            }
        } else {
            self.btnConnect.isUserInteractionEnabled = false
            self.btnConnect.setBackgroundImage(UIImage(named: "connected_gray"), for: UIControl.State.normal)
            
        }
        
        txtCardUID.text = ""
        
        old_tag = current_tag
    }
    @IBAction func ScanDevices(_ sender: UIButton) {
        if bleConnected == true {
            bleManager.cancelPeripheralConnection(connectedReader)
            
        }
        
        if webSocketConnected == true {
            
            web_socket.disconnect()
        }
        
        var done = false
        
        /////////////// LOADING ANIMATION START ///////////////
        self.loadingIndicator.hidesWhenStopped = true
        self.loadingIndicator.style = UIActivityIndicatorView.Style.gray
        self.loadingIndicator.startAnimating();
            
        self.alert.view.addSubview(self.loadingIndicator)
        self.present(self.alert, animated: true, completion: nil)
        done = true
        
        ////////////////////////////////////////////
        
        repeat { // repeat loop mandatory for proper animation display
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        } while !done
        
        AddresPickerData = [String]() // clear current data about readers found
        
        if (rbHTTP.isSelected || rbUDP.isSelected || rbTCP.isSelected) || rbWebSocket.isSelected {
            
        let ip = getIFAddresses().last!.ip
        let mask = getIFAddresses().last!.netmask
        //print("IP: " + ip)
        //print("subnet_mask: " + mask)
        let broadcast_address = getBroadcastAddress(ipAddress: ip, subnetMask: mask)
        let byteArray: [UInt8] = [0x55]
        let client = UDPClient(address: broadcast_address, port: 8880)
        client.enableBroadcast()
        switch client.send(data: byteArray)  {
        case .success:
            let time = Int64(NSDate().timeIntervalSince1970 * 1000)
            while true
            {
                let data = client.recv(1024)
                if data.0 != nil {
                    if data.0?.count == 28
                    {
                        let reader_ip_address = data.1
                        let serialNumber = String(format: "%c%c%c%c%c%c%c%c", data.0![19], data.0![20], data.0![21], data.0![22], data.0![23], data.0![24], data.0![25], data.0![26])
                        
                        self.AddresPickerData.append(reader_ip_address + " / " + serialNumber)
                        
                    }
                }
                let time_now = Int64(NSDate().timeIntervalSince1970 * 1000)
                
                if time_now > time+3000
                {
                    break
                }
            }
            
        case .failure(let error):
            print(error)
        }
            
        if AddresPickerData.count != 0 {
            alert.dismiss(animated: false, completion: nil)
            cbAdresses.text = AddresPickerData[0]
            
            var manual_address = AddresPickerData[0]
            let index = manual_address.firstIndex(of: " ")
            manual_address = String(manual_address[manual_address.startIndex..<index!])
            txtManualAddress.text = manual_address
            self.address_picker.selectedRow(inComponent: 0)
            if (rbHTTP.isSelected || rbUDP.isSelected || rbTCP.isSelected)
            {
                
                self.btnConnect.setBackgroundImage(UIImage(named: "connected_gray"), for: UIControl.State.normal)
                self.btnConnect.isUserInteractionEnabled = false
            }
        } else {
            alert.dismiss(animated: false, completion: nil)
            let notice = UIAlertController(title: "No devices found.", message: ".", preferredStyle: .alert)
            
            self.present(notice, animated: true)
            
            self.AddresPickerData = [String]([""])
            cbAdresses.text = AddresPickerData[0]
            txtManualAddress.text = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                notice.dismiss(animated: false, completion: nil)
            }
            return
            
        }
        client.close()
    // end of if rbHTTP/UDP/TCP check
            
    } else if rbBLE.isSelected == true{
            //cbAdresses.text = "BLE"
            if bleManager.state == .poweredOn {
                let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey:
                    NSNumber(value: false)]
                print("bleManager delegate -> %@", bleManager.delegate)
                bleManager.scanForPeripherals(withServices: nil, options: options)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.bleManager.stopScan()
                    print("Scan stopped (2secs passed)!")
                    self.alert.dismiss(animated: false, completion: nil)
                    if self.AddresPickerData.count != 0{
                        self.cbAdresses.text = self.AddresPickerData[0]
                       self.txtManualAddress.text = self.AddresPickerData[0]
                    self.address_picker.selectedRow(inComponent: 0)
                    }
                    else {
                        let notice = UIAlertController(title: "No BLE devices found.", message: "", preferredStyle: .alert)
                        
                        
                        self.present(notice, animated: true)
                        
                        self.AddresPickerData = [String]()
                        //self.cbAdresses.text = self.AddresPickerData[0]
                        self.cbAdresses.text = ""
                        self.txtManualAddress.text = ""
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            notice.dismiss(animated: false, completion: nil)
                        }
                    }
                }
            } else {
                print("Bluetooth is OFF")
                alert.dismiss(animated: false, completion: {
                
                    let notice = UIAlertController(title: "Bluetooth is OFF", message: "Please turn it ON manually.", preferredStyle: .alert)
                    
                    self.present(notice, animated: true)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        notice.dismiss(animated: false, completion: nil)
                    }
                
                })
            }
        }
    }
    //button functions
    @IBAction func SendUISignalClick(_ sender: Any) {
        
        var resp: String = ""
        self.bleDone = false
        self.webSocketDone = false
        
        var ip_address = ""
        if txtManualAddress.text! == "" {
            if cbAdresses.text == ""{
                let notice = UIAlertController(title: "No device found.", message: "Please use [SCAN] or manual input", preferredStyle: .alert)
                self.present(notice, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    notice.dismiss(animated: false, completion: nil)
                }
                return
            } else {
                ip_address = self.cbAdresses.text!
            }
        } else {
            ip_address = txtManualAddress.text!
        }
        
        if rbHTTP.isSelected == true {
            var byteArray: [UInt8] = [0x55, 0x26, 0xAA, 0x00, 0x01, 0x01, 0xE0]
            let sound_index: Int = sound_picker.selectedRow(inComponent: 0)
            let light_index: Int = light_picker.selectedRow(inComponent: 0)
            
            byteArray[5] = UInt8(sound_index) + 1
            byteArray[4] = UInt8(light_index) + 1
            
            var checksum: UInt8 = 0
            for n in 0...5 {
                checksum = (checksum ^ byteArray[n])
            }
            checksum = checksum + 7
            byteArray[6] = UInt8(checksum)
            
            var command_url = ""
            if ip_address.contains("ON"){
                let index = ip_address.firstIndex(of: " ")
                command_url = String(ip_address[ip_address.startIndex..<index!])
            } else {
                command_url = ip_address
            }
            
            command_url = "http://" + command_url + "/uart1"
            let str_command = byteArray.hexa
            
            resp = http_send(command: str_command, str_url: command_url)
            
            if resp == "Timeout!"{
                return
            }
        } else if rbTCP.isSelected == true {
            
            var command: [UInt8] = [0x55, 0x26, 0xAA, 0x00, 0x01, 0x01, 0xE0]
            
            let sound_index: Int = sound_picker.selectedRow(inComponent: 0)
            let light_index: Int = light_picker.selectedRow(inComponent: 0)
            
            command[5] = UInt8(sound_index) + 1
            command[4] = UInt8(light_index) + 1
            
            var checksum: UInt8 = 0
            for n in 0...5 {
                checksum = (checksum ^ command[n])
            }
            checksum = checksum + 7
            
            command[6] = UInt8(checksum)
            
            var command_url = ""
            if ip_address.contains("ON"){
                let index = ip_address.firstIndex(of: " ")
                command_url = String(ip_address[ip_address.startIndex..<index!])
            } else {
                command_url = ip_address
            }
            
            tcp_send(command: command, ip_address: command_url)
            
        } else if rbUDP.isSelected == true {
            var command: [UInt8] = [0x55, 0x26, 0xAA, 0x00, 0x01, 0x01, 0xE0] //default UI signal command
            
            let sound_index: Int = sound_picker.selectedRow(inComponent: 0)
            let light_index: Int = light_picker.selectedRow(inComponent: 0)
            
            command[5] = UInt8(sound_index) + 1
            command[4] = UInt8(light_index) + 1
            
            var checksum: UInt8 = 0
            for n in 0...5 {
                checksum = (checksum ^ command[n])
            }
            checksum = checksum + 7
            command[6] = UInt8(checksum)
            
            var command_url = ""
            if ip_address.contains("ON"){
                let index = ip_address.firstIndex(of: " ")
                command_url = String(ip_address[ip_address.startIndex..<index!])
            } else {
                command_url = ip_address
            }
            udp_send(command: command, ip_address: command_url)

        } else if rbBLE.isSelected == true {
            
            let selected_row = address_picker.selectedRow(inComponent: 0)
            
            var command: [UInt8] = [0x55, 0x26, 0xAA, 0x00, 0x01, 0x01, 0xE0]
            let sound_index: Int = sound_picker.selectedRow(inComponent: 0)
            let light_index: Int = light_picker.selectedRow(inComponent: 0)
            
            command[5] = UInt8(sound_index) + 1
            command[4] = UInt8(light_index) + 1
            
            var checksum: UInt8 = 0
            for n in 0...5 {
                checksum = (checksum ^ command[n])
            }
            checksum = checksum + 7
            command[6] = UInt8(checksum)
            let command_str = command.hexa
            
            let dataToSend = command_str.hexaData
            if bleConnected == true {
                uFROnlinePeripheral?.writeValue(dataToSend, for: uFRCharacteristic[selected_row], type: CBCharacteristicWriteType.withResponse)
                
                uFROnlinePeripheral.readValue(for: uFRCharacteristic[selected_row])
                
                repeat { // repeat loop untill command is done
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                } while self.bleDone == false
            } else {
                let notice = UIAlertController(title: "No device with BLE connected.", message: "Connect reader with BLE enabled first.", preferredStyle: .alert)
                
                self.present(notice, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    notice.dismiss(animated: false, completion: nil)
                }
            }
            
        } else if rbWebSocket.isSelected == true {
            if webSocketConnected == true {
                
                var command: [UInt8] = [0x55, 0x26, 0xAA, 0x00, 0x01, 0x01, 0xE0] //default UI signal command
                
                let sound_index: Int = sound_picker.selectedRow(inComponent: 0)
                let light_index: Int = light_picker.selectedRow(inComponent: 0)
                
                command[5] = UInt8(sound_index) + 1
                command[4] = UInt8(light_index) + 1
                
                var checksum: UInt8 = 0
                for n in 0...5 {
                    checksum = (checksum ^ command[n])
                }
                checksum = checksum + 7
                command[6] = UInt8(checksum)
                let command_str = command.hexa
                
                
                web_socket!.write(data: command_str.hexaData)
                print(self.webSocketDone)
                repeat { // // repeat loop untill command is done
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                } while self.webSocketDone == false
            } else {
                let notice = UIAlertController(title: "No device with WebSocket connected.", message: "Connect reader with WebSocket enabled first.", preferredStyle: .alert)
                
                
                
                self.present(notice, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    notice.dismiss(animated: false, completion: nil)
                }
                
                return
            }
        }
    } //end of SendUISignal
    
    @IBAction func Connect(_ sender: Any) {
        
        if rbBLE.isSelected {
            
            if bleConnected == true {
                bleManager.cancelPeripheralConnection(connectedReader)
                return
            }
            
            self.bleDone = false
            self.bleManual = false
            
            if txtManualAddress.text == "" || txtManualAddress.text == cbAdresses.text {
               if cbAdresses.text == "" {
                let notice = UIAlertController(title: "No device with BLE found.", message: "Use [SCAN] or enter manually serial number.", preferredStyle: .alert)
                
                
                
                self.present(notice, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    notice.dismiss(animated: false, completion: nil)
                }
                
                return
            }
            
            if cbAdresses.text != "" {
            let search = cbAdresses.text ?? ""
            var index = 0
                for peripheral in foundPeripherals {
                    if peripheral.name == search {
                        uFROnlinePeripheral = foundPeripherals[index]
                    }
                    index += 1
                }
            
            bleManager.connect(uFROnlinePeripheral, options: nil)
            
            loadingIndicator.hidesWhenStopped = true
            loadingIndicator.style = UIActivityIndicatorView.Style.gray
            loadingIndicator.startAnimating();
            
            alert.view.addSubview(loadingIndicator)
            present(alert, animated: true, completion: nil)
            
            repeat { // repeat loop untill command is done
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            } while self.bleDone == false
                
            let notice = UIAlertController(title: "Connected to " + uFROnlinePeripheral.name!, message: "", preferredStyle: .alert)
                
            self.present(notice, animated: true)
    
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                notice.dismiss(animated: false, completion: nil)
            }
                return
            }
        } // if no manual address done
        else { //manual scan + connect
                
            var done = false // used to wait for scan animation load
            self.bleManual = true
            self.bleDone = false
                
                self.loadingIndicator.hidesWhenStopped = true
                self.loadingIndicator.style = UIActivityIndicatorView.Style.gray
                self.loadingIndicator.startAnimating();
                
                self.alert.view.addSubview(self.loadingIndicator)
                self.present(self.alert, animated: true, completion: nil)
                done = true //check previous description
                ////////////////////////////////////////////
                
                repeat { // repeat loop mandatory for proper animation display
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                } while !done //check previous description
                
                let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey:
                    NSNumber(value: false)]
                
            bleManager.scanForPeripherals(withServices: nil, options: options)
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.bleManager.stopScan()
                }
                repeat { // repeat loop untill command is done
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                } while self.bleManager.isScanning
                
                        if self.bleDone {
                            self.bleManager.connect(self.uFROnlinePeripheral, options: nil)
                            
                            repeat { // repeat loop untill command is done
                                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                            } while self.bleDone == false
                            
                            let notice = UIAlertController(title: "Connected to " + self.uFROnlinePeripheral.name!, message: "", preferredStyle: .alert)
                            
                            self.present(notice, animated: true)
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                notice.dismiss(animated: false, completion: {
                                    self.bleManual = false
                                })
                            }
                            return
                        } else {
                            self.alert.dismiss(animated: false, completion: {
                                
                                let notice = UIAlertController(title: "Device not found manually", message: "", preferredStyle: .alert)
                                
                                self.present(notice, animated: true)
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    notice.dismiss(animated: false, completion: {
                                        self.bleManual = false
                                    })
                                }
                        })
                }
        }
        } else if rbWebSocket.isSelected
        {
            
            self.webSocketDone = false
            
            if webSocketConnected == true {
                web_socket.disconnect()
                return
            }
            
                if txtManualAddress.text == "" || txtManualAddress.text == cbAdresses.text {
                let notice = UIAlertController(title: "No device with WebSocket found.", message: "Use [SCAN] or enter manually address", preferredStyle: .alert)
                
                
                
                self.present(notice, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    notice.dismiss(animated: false, completion: nil)
                }
                return
                }
            
            var url: String = ""
           
            if txtManualAddress.text != "" {
                url = "ws://" + (txtManualAddress.text ?? "") + ":8881"
            } else {
                url = cbAdresses.text ?? ""
                let index = url.firstIndex(of: " ")
                url  = String(url[url.startIndex..<index!])
                url = "ws://" + url + ":8881"
            }
            
            web_socket = WebSocket(url: URL(string:url)!)
            web_socket.delegate = self

            web_socket.connect()
            
            self.loadingIndicator.hidesWhenStopped = true
            self.loadingIndicator.style = UIActivityIndicatorView.Style.gray
            self.loadingIndicator.startAnimating();
            
            self.alert.view.addSubview(self.loadingIndicator)
            self.present(self.alert, animated: true, completion: nil)
            
            repeat { // repeat loop untill command is done
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            } while self.webSocketDone == false
            
            if self.webSocketConnected == true {
            let notice = UIAlertController(title: "Connected to " + url, message: "", preferredStyle: .alert)
            
            self.present(notice, animated: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                notice.dismiss(animated: false, completion: nil)
            }
        }
            return
        } // end of if webSocket
    }
    @IBAction func getUID(_ sender: Any) {
        
        txtCardUID.text = ""
        var resp: String = ""
        self.bleDone = false
        self.webSocketDone = false
        
        var ip_address = ""
        if txtManualAddress.text! == "" {
            if cbAdresses.text == "" {
                let notice = UIAlertController(title: "No device found.", message: "Please use [SCAN] or manual input", preferredStyle: .alert)
                self.present(notice, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    notice.dismiss(animated: false, completion: nil)
                }
                return
            } else {
                ip_address = cbAdresses.text!
            }
        } else {
            ip_address = txtManualAddress.text!
        }
        
        if rbHTTP.isSelected == true {
            let str_command: String = "552CAA000000DA" // command to get card UIDs
            var command_url = ""
            if ip_address.contains("ON"){
                let index = ip_address.firstIndex(of: " ")
                command_url = String(ip_address[ip_address.startIndex..<index!])
            } else {
                command_url = ip_address
            }
            
            command_url = "http://" + command_url + "/uart1"
            resp = http_send(command: str_command, str_url: command_url)
            
        } else if rbUDP.isSelected == true {
            let command: [UInt8] = [0x55, 0x2C, 0xAA, 0x00, 0x00, 0x00, 0xDA]
            
            var command_url = ""
            if ip_address.contains("ON"){
                let index = ip_address.firstIndex(of: " ")
                command_url = String(ip_address[ip_address.startIndex..<index!])
            } else {
                command_url = ip_address
            }
            
            resp = udp_send(command: command, ip_address: command_url)
            
            print("UDP_RESP: \(resp)")
            
        } else if rbTCP.isSelected == true {
            let command: [UInt8] = [0x55, 0x2C, 0xAA, 0x00, 0x00, 0x00, 0xDA]
            
            var command_url = ""
            if ip_address.contains("ON"){
                let index = ip_address.firstIndex(of: " ")
                command_url = String(ip_address[ip_address.startIndex..<index!])
            } else {
                command_url = ip_address
            }
            
            resp = tcp_send(command: command, ip_address: command_url)
            
            print ("TCP RESP: \(resp)")
        
        } else if rbBLE.isSelected == true {
            
            let selected_row = address_picker.selectedRow(inComponent: 0)
            if bleConnected == true {
                let command: String = "552CAA000000DA"
                
                let dataToSend = command.hexaData
                
                uFROnlinePeripheral?.writeValue(dataToSend, for: uFRCharacteristic[selected_row], type: CBCharacteristicWriteType.withResponse)
                
                uFROnlinePeripheral.readValue(for: uFRCharacteristic[0])
                repeat { // repeat loop untill command is done
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                } while self.bleDone == false
                
                resp = bleResp ?? ""
            } else {
                let notice = UIAlertController(title: "No device with BLE connected.", message: "Connect reader with BLE enabled first.", preferredStyle: .alert)
                
                
                
                self.present(notice, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    notice.dismiss(animated: false, completion: nil)
                }
                return
            }
            
        } else if rbWebSocket.isSelected == true {
            if webSocketConnected == true {
                let command = "552CAA000000DA"
                web_socket!.write(data: command.hexaData)
                
                repeat { // repeat loop untill command is done
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                    resp = socketResp ?? ""
                } while self.webSocketDone == false
            } else {
                let notice = UIAlertController(title: "No device with WebSocket connected.", message: "Connect reader with WebSocket enabled first.", preferredStyle: .alert)
                
                
                self.present(notice, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    notice.dismiss(animated: false, completion: nil)
                }
                return
            }
        }
        var uid_len: UInt8 = 0
        if resp != ""{
            if resp.count > 14 {
                
                uid_len = resp.hexaBytes[5]
                let start_index = resp.index(resp.startIndex, offsetBy: 14)
                let end_index = resp.index(start_index, offsetBy: Int(uid_len * 2))
                let range = start_index..<end_index
                
                resp = String(resp[range])
            } else {
                print(resp)
                let bytes_resp = resp.hexaBytes
                if bytes_resp.count != 0 {
                if bytes_resp[1] == UInt8(0x08) {
                    resp = "NO CARD"
                } else {
                    resp = ""
                }
            }
            }
            }
        txtCardUID.text = resp
    }
    
    
    @IBAction func sendCommand(_ sender: Any) {
        
        txtResponse.text = ""
        var cmd_response: String = ""
        var str_command: String = txtCommand.text ?? ""
        self.bleDone = false
        self.webSocketDone = false
        
        var ip_address = ""
        if txtManualAddress.text! == "" {
            if cbAdresses.text == "" {
                let notice = UIAlertController(title: "No device found.", message: "Please use [SCAN] or manual input", preferredStyle: .alert)
                self.present(notice, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    notice.dismiss(animated: false, completion: nil)
                }
                return
            } else {
                ip_address = cbAdresses.text!
            }
        } else {
            ip_address = txtManualAddress.text!
        }
        
        if str_command == "" {
            let notice = UIAlertController(title: "Command not provided.", message: "You need to enter hex command in [Command] field", preferredStyle: .alert)
            
            self.present(notice, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                notice.dismiss(animated: false, completion: nil)
            }
            return
        }
        
        str_command = str_command.uppercased()
        
        if str_command.contains("XX") {
            str_command = String(str_command.prefix(12))
            let byte_command = str_command.hexaBytes
            var new_command = [UInt8](arrayLiteral:0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
            var checksum: UInt8 = 0
            
            for i in 0...(byte_command.count-1) {
                new_command[i] = byte_command[i]
                checksum = (checksum ^ byte_command[i])
            }
            
            checksum = checksum + 7
            new_command[6] = UInt8(checksum)
            str_command = new_command.hexa
            
        }
        
        if rbHTTP.isSelected == true {
            var command_url = ""
            if ip_address.contains("ON"){
                let index = ip_address.firstIndex(of: " ")
                command_url = String(ip_address[ip_address.startIndex..<index!])
            } else {
                command_url = ip_address
            }
            
            command_url = "http://" + command_url + "/uart1"
            cmd_response = http_send(command: str_command, str_url: command_url)
            
        } else if rbTCP.isSelected == true {
            var ip_address_short = ""
            if ip_address.contains("ON"){
                let index = ip_address.firstIndex(of: " ")
                ip_address_short = String(ip_address[ip_address.startIndex..<index!])
            } else {
                ip_address_short = ip_address
            }
            cmd_response = tcp_send(command: str_command.hexaBytes, ip_address: ip_address_short)
        } else if rbUDP.isSelected == true {
            var ip_address_short = ""
            if ip_address.contains("ON"){
                let index = ip_address.firstIndex(of: " ")
                ip_address_short = String(ip_address[ip_address.startIndex..<index!])
            } else {
                ip_address_short = ip_address
            }
            udp_send(command: str_command.hexaBytes, ip_address: ip_address_short)
        } else if rbBLE.isSelected == true {
            let selected_row = address_picker.selectedRow(inComponent: 0)
            let dataToSend = str_command.hexaData
            
            uFROnlinePeripheral?.writeValue(dataToSend, for: uFRCharacteristic[selected_row], type: CBCharacteristicWriteType.withResponse)
            
            uFROnlinePeripheral.readValue(for: uFRCharacteristic[selected_row])
            
            repeat { // repeat loop untill command is done
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            } while self.bleDone == false
            
            cmd_response = bleResp ?? ""
        } else if rbWebSocket.isSelected == true {
            let dataToSend = str_command.hexaData
            web_socket!.write(data: dataToSend)
            
            repeat { // repeat loop untill command is done
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                cmd_response = socketResp ?? "ERROR"
            } while self.webSocketDone == false
        }
        
        txtResponse.text = cmd_response
    }
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    // MARK: - Send request functions
    
    func http_send(command: String, str_url: String) -> String {
        
        var request = URLRequest(url: URL(string: str_url)!)
        var httpResponse: String?
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.timeoutInterval = 2.0
        request.httpBody = command.data(using: .utf8)
    
        var done = false
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                let response = response as? HTTPURLResponse,
                error == nil else {
                    // check for fundamental networking error
                    print("error", error ?? "Unknown error")
                    done = true
                    return
            }
            
            guard (200 ... 299) ~= response.statusCode else {
                // check for http errors
                print("statusCode should be 2xx, but is \(response.statusCode)")
                print("response = \(response)")
                done = true
                return
            }
            
            httpResponse = String(data: data, encoding: .utf8)
            print("httpResponse = \(String(describing: httpResponse))")
            done = true
        }
        task.resume()
        repeat {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        } while !done
        print(" HTTP_RESP: " + (httpResponse ?? "Timeout!"))
        
        return httpResponse ?? ""
    }
    
    func udp_send(command: [UInt8], ip_address: String) -> String {
        
        var ip_address_short = ""
        if ip_address.contains("ON"){
            let index = ip_address.firstIndex(of: " ")
            ip_address_short = String(ip_address[ip_address.startIndex..<index!])
        } else {
            ip_address_short = ip_address
        }
        
        var udpResponse: String?
        let client = UDPClient(address: ip_address_short, port: 8881)
        
        switch client.send(data: command)  {
        case .success:
            let time = Int64(NSDate().timeIntervalSince1970 * 1000)
            while true
            {
                let data = client.recv(1024)
                
                let time_now = Int64(NSDate().timeIntervalSince1970 * 1000)
                
                if data.0 != nil {
                    print(data.0?.hexa ?? "")
                    udpResponse = data.0?.hexa ?? ""
                    break
                }
                if time_now > time+1000
                {
                    break
                }
            }
        case .failure(let error):
            print(error)
        }
        
        return udpResponse ?? ""
        
    }
    
    func tcp_send(command: [UInt8], ip_address: String) -> String{
        
        var ip_address_short = ""
        if ip_address.contains("ON"){
            let index = ip_address.firstIndex(of: " ")
            ip_address_short = String(ip_address[ip_address.startIndex..<index!])
        } else {
            ip_address_short = ip_address
        }
        
        var tcpResponse: String?
        let client = TCPClient(address: ip_address_short, port: 8881)
        switch client.connect(timeout: 1){
            
        case .success:
            switch client.send(data: command){
            case .success:
                let time = Int64(NSDate().timeIntervalSince1970 * 1000)
                while true
                {
                    let data = client.read(1024)
                    
                    let time_now = Int64(NSDate().timeIntervalSince1970 * 1000)
                    
                    if data != nil {
                        print(data?.hexa ?? "")
                        tcpResponse = data?.hexa ?? ""
                        break
                    }
                    if time_now > time+1000
                    {
                        break
                    }
                }
                
            case .failure (let error):
                print(error)
                client.close()
            }
        case .failure (let error):
            print(error)
            client.close()
        }
        client.close()
        return tcpResponse ??  ""
    }
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // MARK: - Scan helper functions
    
    struct NetInfo {
        let ip: String
        let netmask: String
    }
    
    func getIFAddresses() -> [NetInfo] {
        var addresses = [NetInfo]()
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr;
            while ptr != nil {
                let flags = Int32((ptr?.pointee.ifa_flags)!)
                var addr = ptr?.pointee.ifa_addr.pointee
                let interface = ptr?.pointee
                // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
                if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                    if addr?.sa_family == UInt8(AF_INET) || addr?.sa_family == UInt8(AF_INET6) {
                        if let name: String = String(cString: (interface?.ifa_name)!), name == "en0" {
                            // Convert interface address to a human readable string:
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            if (getnameinfo(&addr!, socklen_t((addr?.sa_len)!), &hostname, socklen_t(hostname.count),
                                            nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                                if let address = String.init(validatingUTF8:hostname) {
                                    
                                    var net = ptr?.pointee.ifa_netmask.pointee
                                    var netmaskName = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                                    getnameinfo(&net!, socklen_t((net?.sa_len)!), &netmaskName, socklen_t(netmaskName.count),
                                                nil, socklen_t(0), NI_NUMERICHOST)// == 0
                                    if let netmask = String.init(validatingUTF8:netmaskName) {
                                        addresses.append(NetInfo(ip: address, netmask: netmask))
                                    }
                                }
                            }
                        }
                        
                    }
                }
                ptr = ptr?.pointee.ifa_next
            }
            freeifaddrs(ifaddr)
        }
        return addresses
    }
    
    func getBroadcastAddress(ipAddress: String, subnetMask: String) -> String {
        
        let ipAdressArray = ipAddress.split(separator: ".")
        let subnetMaskArray = subnetMask.split(separator: ".")
        guard ipAdressArray.count == 4 && subnetMaskArray.count == 4 else {
            return "255.255.255.255"
        }
        var broadcastAddressArray = [String]()
        for i in 0..<4 {
            let ipAddressByte = UInt8(ipAdressArray[i]) ?? 0
            let subnetMaskbyte = UInt8(subnetMaskArray[i]) ?? 0
            let broadcastAddressByte = ipAddressByte | ~subnetMaskbyte
            broadcastAddressArray.append(String(broadcastAddressByte))
        }
        return broadcastAddressArray.joined(separator: ".")
    }
    
    func stringToBytes(_ string: String) -> [UInt8]? {
        let length = string.count
        if length & 1 != 0 {
            return nil
        }
        var bytes = [UInt8]()
        bytes.reserveCapacity(length/2)
        var index = string.startIndex
        for _ in 0..<length/2 {
            let nextIndex = string.index(index, offsetBy: 2)
            if let b = UInt8(string[index..<nextIndex], radix: 16) {
                bytes.append(b)
            } else {
                return nil
            }
            index = nextIndex
        }
        return bytes
    }
    
    func byteArrayToHexString( _ arr:[UInt8] ) -> String {
        
        var result = ""
        
        for byte in 0...arr.count {
            
            var hex = String( arr[byte], radix: 16 )
            if hex.count == 1 {
                
                hex = "0" + hex
            }
            
            result.append( hex )
            result.append( "-" )
        }
        
        result.removeLast()
        
        return result.uppercased()
    }
    
    
    // MARK: - Extension functions
} // End of ViewController class
extension String {
    var hexaBytes: [UInt8] {
        var position = startIndex
        return (0..<count/2).compactMap { _ in
            defer { position = index(position, offsetBy: 2) }
            return UInt8(self[position...index(after: position)], radix: 16)
        }
    }
    var hexaData: Data { return hexaBytes.data }
}

extension Collection where Element == UInt8 {
    var data: Data {
        return Data(self)
    }
    var hexa: String {
        return map{ String(format: "%02X", $0) }.joined()
    }
}









