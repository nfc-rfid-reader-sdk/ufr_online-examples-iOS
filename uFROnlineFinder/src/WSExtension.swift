//
//  WSExtension.swift
//  uFROnlineFinder
//
//  Created by D-Logic on 9/24/19.
//  Copyright © 2019 Digital Logic. All rights reserved.
//

import Foundation
import Starscream

extension MainViewController: WebSocketDelegate {
    
    func websocketDidConnect(socket: WebSocketClient) {
        
        //print("-----------------------")
        print("websocket is connected")
        //print("-----------------------")
        
        self.btnConnect.setBackgroundImage(UIImage(named: "connected_1"), for: UIControl.State.normal)
        self.btnConnect.isEnabled = true
        
        self.webSocketConnected = true
        
        self.alert.dismiss(animated: false, completion: {
        self.webSocketDone = true
          
        })
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        
        self.btnConnect.isUserInteractionEnabled = true
        self.btnConnect.setBackgroundImage(UIImage(named: "connect"), for: UIControl.State.normal)
        self.btnConnect.isEnabled = true
        self.webSocketConnected = false
        
        if let e = error as? WSError {
            
            let notice = UIAlertController(title: "Failed to connect!" , message: error?.localizedDescription, preferredStyle: .alert)
            self.alert.dismiss(animated: false, completion: {
                
            self.present(notice, animated: true)
            
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                notice.dismiss(animated: false, completion: nil)
                self.webSocketDone = true
            }
            
            print("websocket is disconnected: \(e.message)")
        
        } else if let e = error {
            let notice = UIAlertController(title: "Failed to connect!" , message: error?.localizedDescription, preferredStyle: .alert)
            
            self.alert.dismiss(animated: false, completion: {
                self.present(notice, animated: true)
                
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                notice.dismiss(animated: false, completion: nil)
                self.webSocketDone = true
            }
            
            print("websocket is disconnected: \(e.localizedDescription)")
        } else {
            print("websocket disconnected")
            self.webSocketDone = true
        }
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        print("Received text: \(text)")
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        
        self.socketResp = ""
        print("Received data: \(data.hexa)")
        self.socketResp = data.hexa
        self.webSocketDone = true
    }
    
    
}
