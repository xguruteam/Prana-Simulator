//
//  ViewController.swift
//  Wagner Simulator
//
//  Created by Guru on 3/7/19.
//  Copyright © 2019 Guru. All rights reserved.
//

import UIKit
import CoreBluetooth
import CoreMotion

class ViewController: UIViewController {
    
//    let PM_LOCAL_NAME = "Prana Tech2"
//    let PM_LOCAL_NAME = "iPhone"
    let PM_LOCAL_NAME = "Prana Tech"

    let RX_SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
//    let RX_CHAR_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
//    let TX_CHAR_UUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
    
    let char_rx = CBMutableCharacteristic(type: CBUUID(string: "6e400002-b5a3-f393-e0a9-e50e24dcca9e"), properties: [.writeWithoutResponse], value: nil, permissions: [.writeable])
    let char_tx = CBMutableCharacteristic(type: CBUUID(string: "6e400003-b5a3-f393-e0a9-e50e24dcca9e"), properties: [.read, .notify], value: nil, permissions: [.readable])
    
    @IBOutlet weak var btStartStop: UIButton!
    @IBOutlet weak var breathingSlider: UISlider!
    @IBOutlet weak var btUpright: UIButton!
    @IBOutlet weak var switchTest: UISwitch!
    
    @IBOutlet weak var btn1: UIButton!
    @IBOutlet weak var btn2: UIButton!
    @IBOutlet weak var btn3: UIButton!
    
    var status: Bool = false
    let peripheralManager = CBPeripheralManager(delegate: nil, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
    var central: CBCentral!
    
    var interval = 1.0 / 20.0
    var sendTimer: Timer?
    var isSending = false
    var ready = false
    
    let motion = CMMotionManager()
    
    
    var buffTimer: DispatchSourceTimer?
    var len = 0
    var pos = 0
    let mtu = 20
    var buff: Data!
    var needSendUpright = false
    
    var testDataOffest: Int = 0
    var isTesting = false
    var testType = 0
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        btStartStop.layer.cornerRadius = 50
        
        self.peripheralManager.delegate = self
        btStartStop.setTitle("Start", for: .normal)
        btStartStop.alpha = 0.5
        
        breathingSlider.isHidden = true
        btUpright.isHidden = true
        
        switchTest.isOn = false
        onTestChange(switchTest)
        onTestTypeChange(btn1)
    }
    
    @IBAction func onStartStop(_ sender: Any) {
        if self.status == false {
            self.status = true
            btStartStop.setTitle("Stop", for: .normal)
            btStartStop.alpha = 1
            
            stopSend()
            stopAdvertising()
            
            startAdvertising()
            
            switchTest.isEnabled = false
            btn1.isEnabled = false
            btn2.isEnabled = false
            btn3.isEnabled = false
        }
        else {
            self.status = false
            btStartStop.setTitle("Start", for: .normal)
            btStartStop.alpha = 0.5
            
            stopAdvertising()
            stopSend()
            
            switchTest.isEnabled = true
            btn1.isEnabled = true
            btn2.isEnabled = true
            btn3.isEnabled = true
        }
    }
    
    @IBAction func onBreathingValueChanged(_ sender: UISlider) {
    }
    
    @IBAction func onTestChange(_ sender: UISwitch) {
        if sender.isOn {
            isTesting = true
            btn1.isHidden = false
            btn2.isHidden = false
            btn3.isHidden = false
        }
        else {
            isTesting = false
            btn1.isHidden = true
            btn2.isHidden = true
            btn3.isHidden = true
        }
    }
    
    @IBAction func onUpright(_ sender: Any) {
        needSendUpright = true
    }
    
    @IBAction func onTestTypeChange(_ sender: UIButton) {
        testType = sender.tag - 1
        btn1.alpha = 0.5
        btn2.alpha = 0.5
        btn3.alpha = 0.5
        
        switch sender.tag {
        case 1:
            btn1.alpha = 1.0
        case 2:
            btn2.alpha = 1.0
        case 3:
            btn3.alpha = 1.0
        default:
            break
        }
    }
    
    func startAdvertising() {
        let service_rx = CBMutableService(type: CBUUID(string: RX_SERVICE_UUID), primary: true)
        service_rx.characteristics = [self.char_rx, self.char_tx]
        self.peripheralManager.add(service_rx)
        
        self.peripheralManager.startAdvertising([
            CBAdvertisementDataLocalNameKey: PM_LOCAL_NAME,
            CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: RX_SERVICE_UUID)],
            ])
    }
    
    func stopAdvertising() {
        self.peripheralManager.stopAdvertising()
        self.peripheralManager.removeAllServices()
    }
    

    func startSend() {
        print("start send")
        stopSend()
            
        isSending = true
        DispatchQueue.main.async {
            self.breathingSlider.isHidden = false
            self.btUpright.isHidden = false
        }
        
        if self.motion.isAccelerometerAvailable {
            self.motion.accelerometerUpdateInterval = 1.0 / 20.0
            self.motion.startAccelerometerUpdates()
        }
        
        testDataOffest = 0
        
        self.sendTimer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(sendLoop), userInfo: nil, repeats: true)
        
    }
    
    @objc func sendLoop() {
        if self.buffTimer != nil {
            print("buff is not ready")
            return
        }
        
        var x = 0.0
        var y = 0.0
        var z = 0.0
        var s = Double(self.breathingSlider.value)
        var r = 0.0
        
        if let data = self.motion.accelerometerData {
            x = data.acceleration.x
            y = data.acceleration.y
            z = data.acceleration.z
        }
        
        if self.needSendUpright {
            let a = "Upright"
            let c = "\(x)"
            let d = "\(y)"
            let e = "\(z)"
            let response = "\(a),\(c),\(d),\(e)"
            guard let raw = response.data(using: .utf8) else {
                return
            }
            
            self.buff = raw
            self.needSendUpright = false
            
        }
        else {
//            if isTesting {
//                let data = testData[testType]
//                let count = data["xSensor"]!.count
//                if self.testDataOffest < count {
//                    x = data["xSensor"]![self.testDataOffest]
//                    y = data["ySensor"]![self.testDataOffest]
//                    z = data["zSensor"]![self.testDataOffest]
//                    s = data["BreathSensor"]![self.testDataOffest]
//                    r = data["RotationSensor"]![self.testDataOffest]
//                    self.testDataOffest += 1
//                }
//            }
            let a = "20hz"
            let b = "\(s)"
            let c = "\(x)"
            let d = "\(y)"
            let e = "\(z)"
            let f = "\(r)"
            let g = "99"
            let response = "\(a),\(b),\(c),\(d),\(e),\(f),\(g)"
            guard let raw = response.data(using: .utf8) else {
                return
            }
            
            self.buff = raw
            
        }
        
        self.startBuff()
    }
    
    func stopSend() {
        print("stop send")
        
        isSending = false
        
        DispatchQueue.main.async {
            self.breathingSlider.isHidden = true
            self.btUpright.isHidden = true
        }
        
        self.motion.stopAccelerometerUpdates()
        
        guard let timer = self.sendTimer else {
            return
        }
        
        timer.invalidate()
        self.sendTimer = nil
    }
    
    
    func startBuff() {
//        print("start buff")
        
        len = self.buff.count
        pos = 0
        
        
        let queue = DispatchQueue(label: "sendingQueue", attributes: .concurrent)
        
        buffTimer?.cancel()        // cancel previous timer if any
        
        buffTimer = DispatchSource.makeTimerSource(queue: queue)
        
        buffTimer?.schedule(deadline: .now(), repeating: .milliseconds(10), leeway: .nanoseconds(0))
        
        // or, in Swift 3:
        //
        // timer?.scheduleRepeating(deadline: .now(), interval: .seconds(5), leeway: .seconds(1))
        
        buffTimer?.setEventHandler { [weak self] in // `[weak self]` only needed if you reference `self` in this closure and you want to prevent strong reference cycle
            self?.buffBlock()
        }
        
        buffTimer?.resume()
    }
    
    func stopBuff() {
//        print("stop buff")
        buffTimer?.cancel()
        buffTimer = nil
    }

    func buffBlock() {
//        print("buffBlock")
        
        var raw: Data
        
        var dlen = 0
        if len < mtu {
            dlen = len
        }
        else {
            dlen = mtu
        }
        raw = buff.subdata(in: pos ..< (pos + dlen))
        
        let didSent = self.peripheralManager.updateValue(raw, for: self.char_tx, onSubscribedCentrals: nil)
//        print("didSent \(didSent)")
        if !didSent {
            return
        }
//        print(raw)

        pos += dlen
        len -= dlen

        if len <= 0 {
            stopBuff()
            return
        }
    }
    
}

extension ViewController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if error != nil {
            print("didAdd service error:\(error?.localizedDescription)")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if error != nil {
            print("didStartAdv error:\(error?.localizedDescription)")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("didSubscribe")
        self.central = central
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("didUnSubscribe")
        self.central = nil
        self.stopSend()
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            
            guard let command = String(data: request.value!, encoding: .utf8) else {
                continue
            }

            print("\(command)")

            if command.contains("start20hzdata") {
                self.startSend()
            }
            else if command.contains("stopData") {
                self.stopSend()
            }
            
        }
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        print("ready")
        ready = true
    }
}
