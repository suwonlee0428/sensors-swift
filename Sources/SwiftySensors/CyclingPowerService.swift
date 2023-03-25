//
//  CyclingPowerSensor.swift
//  SwiftySensors
//
//  https://github.com/kinetic-fit/sensors-swift
//
//  Copyright © 2017 Kinetic. All rights reserved.
//

import CoreBluetooth
import Signals

//
// https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.service.cycling_power.xml
//
/// :nodoc:
open class CyclingPowerService: Service, ServiceProtocol {
    
    public static var uuid: String { return "1818" }
    
    public static var characteristicTypes: Dictionary<String, Characteristic.Type> = [
        Measurement.uuid:       Measurement.self,
        Feature.uuid:           Feature.self,
        Vector.uuid:            Vector.self,
        SensorLocation.uuid:    SensorLocation.self,
        ControlPoint.uuid:      ControlPoint.self,
        WahooTrainer.uuid:      WahooTrainer.self
    ]
    
    public var measurement: Measurement? { return characteristic() }
    
    public var feature: Feature? { return characteristic() }
    
    public var sensorLocation: SensorLocation? { return characteristic() }
    
    public var controlPoint: ControlPoint? { return characteristic() }
    
    public var wahooTrainer: WahooTrainer? { return characteristic() }
    
    
    //
    // https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.cycling_power_measurement.xml
    //
    open class Measurement: Characteristic {
        
        public static let uuid: String = "2A63"
        
        open private(set) var instantaneousPower: UInt?
        
        open private(set) var speedKPH: Double?
        
        open private(set) var crankRPM: Double?
        
        open var wheelCircumferenceCM: Double = 213.3
        
        open private(set) var measurementData: CyclingPowerSerializer.MeasurementData? {
            didSet {
                guard let current = measurementData, current.instantaneousPower >= 0 else { return }
                instantaneousPower = UInt(current.instantaneousPower)
                
                guard let previous = oldValue else { return }
                speedKPH = CyclingSerializer.calculateWheelKPH(current, previous: previous, wheelCircumferenceCM: wheelCircumferenceCM, wheelTimeResolution: 2048)
                crankRPM = CyclingSerializer.calculateCrankRPM(current, previous: previous)
            }
        }
        
        required public init(service: Service, cbc: CBCharacteristic) {
            super.init(service: service, cbc: cbc)
            
            cbCharacteristic.notify(true)
        }
        
        override open func valueUpdated() {
            // cbCharacteristic is nil?
            if let value = cbCharacteristic.value {
                measurementData = CyclingPowerSerializer.readMeasurement(value)
            }
            super.valueUpdated()
        }
        
    }
    
    //
    // https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.cycling_power_vector.xml
    //
    open class Vector: Characteristic {
        
        public static let uuid: String = "2A64"
        
        open private(set) var vectorData: CyclingPowerSerializer.VectorData? {
            didSet {
//                guard let current = measurementData else { return }
//                instantaneousPower = UInt(current.instantaneousPower)
//
//                guard let previous = oldValue else { return }
//                speedKPH = CyclingSerializer.calculateWheelKPH(current, previous: previous, wheelCircumferenceCM: wheelCircumferenceCM, wheelTimeResolution: 2048)
//                crankRPM = CyclingSerializer.calculateCrankRPM(current, previous: previous)
            }
        }
        
        required public init(service: Service, cbc: CBCharacteristic) {
            super.init(service: service, cbc: cbc)
            
            cbCharacteristic.notify(true)
        }
        
        override open func valueUpdated() {
            if let value = cbCharacteristic.value {
                vectorData = CyclingPowerSerializer.readVector(value)
            }
            super.valueUpdated()
        }
        
    }
    
    //
    // https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.cycling_power_feature.xml
    //
    open class Feature: Characteristic {
        
        public static let uuid: String = "2A65"
        
        open private(set) var features: CyclingPowerSerializer.Features?
        
        required public init(service: Service, cbc: CBCharacteristic) {
            super.init(service: service, cbc: cbc)
            
            cbCharacteristic.read()
        }
        
        override open func valueUpdated() {
            if let value = cbCharacteristic.value {
                features = CyclingPowerSerializer.readFeatures(value)
            }
            
            super.valueUpdated()
            
            if let service = service {
                service.sensor.onServiceFeaturesIdentified => (service.sensor, service)
            }
        }
    }
    
    
    
    //
    // https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.sensor_location.xml
    //
    open class SensorLocation: Characteristic {
        
        public static let uuid: String = "2A5D"
        
        open private(set) var location: CyclingSerializer.SensorLocation?
        
        required public init(service: Service, cbc: CBCharacteristic) {
            super.init(service: service, cbc: cbc)
            
            cbCharacteristic.read()
        }
        
        override open func valueUpdated() {
            if let value = cbCharacteristic.value {
                location = CyclingSerializer.readSensorLocation(value)
            }
            super.valueUpdated()
        }
    }
    
    
    
    //
    // https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.cycling_power_control_point.xml
    //
    open class ControlPoint: Characteristic {
        
        public static let uuid: String = "2A66"
        
        static let writeType = CBCharacteristicWriteType.withResponse
        
        required public init(service: Service, cbc: CBCharacteristic) {
            super.init(service: service, cbc: cbc)
            
            cbCharacteristic.notify(true)
        }
        
        override open func valueUpdated() {
            // TODO: Process this response
            super.valueUpdated()
        }
    }
    
    open class WahooTrainer: Characteristic {
        
        /// Wahoo Trainer Characteristic UUID
        public static let uuid: String = "A026E005-0A7D-4AB3-97FA-F1500F9FEB8B"
        
        /// Inserts this Characteristic's type onto the Cycling Power Service's known Characteristic types.
        public static func activate() {
            CyclingPowerService.characteristicTypes[uuid] = WahooTrainer.self
            SensorManager.logSensorMessage?("activate")
        }
        
        /**
         Initializes a Wahoo Trainer Characteristic, turns on notifications and unlocks the Trainer.
         
         - parameter service: The Cycling Power Service
         - parameter cbc: The backing CoreBluetooth Characteristic
         */
        required public init(service: Service, cbc: CBCharacteristic) {
            super.init(service: service, cbc: cbc)
            
            cbCharacteristic.notify(true)
            
            // Wahoo Trainers have to be "unlocked" before they will respond to messages
            cbCharacteristic.write(Data(WahooTrainerSerializer.unlockCommand()), writeType: .withResponse)
            
            service.sensor.onStateChanged.subscribe(with: self) { [weak self] sensor in
                if sensor.peripheral.state == .disconnected {
                    self?.ergWriteTimer?.invalidate()
                }
            }
        }
        
        override open func valueUpdated() {
            // ToDo: ... ?
            super.valueUpdated()
        }
        
        /**
         Put the trainer into Level mode.
         
         - parameter level: The target level.
         */
        open func setResistanceMode(resistance: Float) {
            ergWriteTimer?.invalidate()
            cbCharacteristic.write(Data(WahooTrainerSerializer.setResistanceMode(resistance)), writeType: .withResponse)
        }
        
        open func setStandardMode(level: UInt8) {
            ergWriteTimer?.invalidate()
            cbCharacteristic.write(Data(WahooTrainerSerializer.setStandardMode(level: level)), writeType: .withResponse)
        }
        
        // Minimum interval between ERG writes to the trainer to give it time to react and apply a new setting.
        private let ErgWriteDelay: TimeInterval = 2
        
        /**
         Put the trainer into ERG mode and set the target wattage.
         This will delay the write if a write already occurred within the last `ErgWriteDelay` seconds.
         
         - parameter watts: The target wattage.
         */
        open func setErgMode(_ watts: UInt16) {
            ergWriteWatts = watts
            
            if ergWriteTimer == nil || !ergWriteTimer!.isValid {
                writeErgWatts()
                ergWriteTimer = Timer(timeInterval: ErgWriteDelay, target: self, selector: #selector(writeErgWatts(_:)), userInfo: nil, repeats: true)
                RunLoop.main.add(ergWriteTimer!, forMode: .common)
            }
        }
        
        open func setSimMode(weight: Float, rollingResistanceCoefficient: Float, windResistanceCoefficient: Float) {
            ergWriteTimer?.invalidate()
            cbCharacteristic.write(Data(WahooTrainerSerializer.seSimMode(weight: weight, rollingResistanceCoefficient: rollingResistanceCoefficient, windResistanceCoefficient: windResistanceCoefficient)), writeType: .withResponse)
        }
        
        open func setSimCRR(_ rollingResistanceCoefficient: Float) {
            cbCharacteristic.write(Data(WahooTrainerSerializer.setSimCRR(rollingResistanceCoefficient)), writeType: .withResponse)
        }
        
        open func setSimWindResistance(_ windResistanceCoefficient: Float) {
            cbCharacteristic.write(Data(WahooTrainerSerializer.setSimWindResistance(windResistanceCoefficient)), writeType: .withResponse)
        }
        
        open func setSimGrade(_ grade: Float) {
            cbCharacteristic.write(Data(WahooTrainerSerializer.setSimGrade(grade)), writeType: .withResponse)
        }
        
        open func setSimWindSpeed(_ metersPerSecond: Float)  {
            cbCharacteristic.write(Data(WahooTrainerSerializer.setSimWindSpeed(metersPerSecond)), writeType: .withResponse)
        }
        
        open func setWheelCircumference(_ millimeters: Float) {
            cbCharacteristic.write(Data(WahooTrainerSerializer.setWheelCircumference(millimeters)), writeType: .withResponse)
        }
        
        private var ergWriteWatts: UInt16?
        private var ergWriteTimer: Timer?
        /// Private function to execute an ERG write
        @objc private func writeErgWatts(_ timer: Timer? = nil) {
            if let writeWatts = ergWriteWatts, cbCharacteristic.write(Data(WahooTrainerSerializer.seErgMode(writeWatts)), writeType: .withResponse) {
                ergWriteWatts = nil
            } else {
                ergWriteTimer?.invalidate()
            }
        }
    }
    
}

    
}
