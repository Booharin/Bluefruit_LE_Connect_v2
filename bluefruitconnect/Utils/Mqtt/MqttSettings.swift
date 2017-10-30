//
//  MqttSettings.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Antonio García on 30/07/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import Foundation


class MqttSettings
{
    // Singleton
    static let sharedInstance = MqttSettings()
    
    // Config
    static let defaultServerAddress = "io.adafruit.com";
    static let defaultServerPort = 1883;

    // Constants
    private static let preferences_serveraddress = "serveraddress";
    private static let preferences_serverport = "serverport";
    private static let preferences_publishtopic = "publishtopic";
    private static let preferences_publishqos = "publishqos";
    private static let preferences_publishenabled = "publishenabled";
    private static let preferences_subscribetopic = "subscribetopic";
    private static let preferences_subscribeqos = "subscribeqos";
    private static let preferences_subscribebehaviour = "subscribebehaviour";
    private static let preferences_subscribeenabled = "subscribeenabled";
    private static let preferences_connected = "connected";
    private static let preferences_username = "username";
    private static let preferences_password = "password";
    private static let preferences_cleansession = "cleansession";
    private static let preferences_sslconnection = "sslconnection";

    // Data
    enum SubscribeBehaviour : Int {
        case LocalOnly = 0
        case Transmit = 1
    }
    
    enum PublishFeed : Int {
        case RX = 0
        case TX = 1
    }
    
    var serverAddress : String? {
        get {
          return loadStringPref(key: MqttSettings.preferences_serveraddress, defaultValue: MqttSettings.defaultServerAddress)
        }
        
        set {
          saveStringPref(key: MqttSettings.preferences_serveraddress, value: newValue)
        }
    }
    
    var serverPort : Int {
        get {
          return loadIntPref(key: MqttSettings.preferences_serverport, defaultValue: MqttSettings.defaultServerPort)
        }
        
        set {
          saveIntPref(key: MqttSettings.preferences_serverport, value: newValue)
        }
    }

    var isConnected : Bool {
        get {
          return loadBoolPref(key: MqttSettings.preferences_connected, defaultValue: false)
        }
        
        set {
          saveBoolPref(key: MqttSettings.preferences_connected, value: newValue)
        }
    }
    
    var isPublishEnabled : Bool {
        get {
          return loadBoolPref(key: MqttSettings.preferences_publishenabled, defaultValue: true)
        }
        
        set {
          saveBoolPref(key: MqttSettings.preferences_publishenabled, value: newValue)
        }
    }
    
    var isSubscribeEnabled : Bool {
        get {
          return loadBoolPref(key: MqttSettings.preferences_subscribeenabled, defaultValue: true)
        }
        
        set {
          saveBoolPref(key: MqttSettings.preferences_subscribeenabled, value: newValue)
        }
    }
    
    func getPublishQos(index:Int) -> MqttManager.MqttQos {
      let value = loadIntPref(key: MqttSettings.preferences_publishqos+"\(index)", defaultValue: MqttManager.MqttQos.AtMostOnce.rawValue)
        return MqttManager.MqttQos(rawValue: value)!
    }
    
    func setPublishQos(index:Int, qos:MqttManager.MqttQos) {
      saveIntPref(key: MqttSettings.preferences_publishqos+"\(index)", value: qos.rawValue)
    }
    
    var subscribeQos : MqttManager.MqttQos {
        get {
          let value = loadIntPref(key: MqttSettings.preferences_subscribeqos, defaultValue: MqttManager.MqttQos.AtMostOnce.rawValue)
            return MqttManager.MqttQos(rawValue: value)!
        }
        
        set {
          saveIntPref(key: MqttSettings.preferences_subscribeqos, value: newValue.rawValue)
        }
    }
    
    func getPublishTopic(index:Int) -> String? {
      return loadStringPref(key: MqttSettings.preferences_publishtopic+"\(index)", defaultValue: nil)
    }
    
    func setPublishTopic(index:Int, topic:String?) {
      saveStringPref(key: MqttSettings.preferences_publishtopic+"\(index)", value: topic)
    }

    var subscribeBehaviour : SubscribeBehaviour {
        get {
          let value = loadIntPref(key: MqttSettings.preferences_subscribebehaviour, defaultValue: SubscribeBehaviour.LocalOnly.rawValue)
            return SubscribeBehaviour(rawValue: value)!
        }
        
        set {
          saveIntPref(key: MqttSettings.preferences_subscribebehaviour, value: newValue.rawValue)
        }
    }
    
    var subscribeTopic : String? {
        get {
          return loadStringPref(key: MqttSettings.preferences_subscribetopic, defaultValue: nil)
        }
        
        set {
          saveStringPref(key: MqttSettings.preferences_subscribetopic, value: newValue)
        }
    }
    
    
    var username : String? {
        get {
          return loadStringPref(key: MqttSettings.preferences_username, defaultValue: nil)
        }
        
        set {
          saveStringPref(key: MqttSettings.preferences_username, value: newValue)
        }
    }
    
    var password : String? {
        get {
          return loadStringPref(key: MqttSettings.preferences_password, defaultValue: nil)
        }
        
        set {
          saveStringPref(key: MqttSettings.preferences_password, value: newValue)
        }
    }

    var isCleanSession : Bool {
        get {
          return loadBoolPref(key: MqttSettings.preferences_cleansession, defaultValue: true)
        }
        
        set {
          saveBoolPref(key: MqttSettings.preferences_cleansession, value: newValue)
        }
    }
    
    // Common load and save
    func saveStringPref(key : String, value : String?) {
      let defaults = UserDefaults.standard
      defaults.set(value, forKey: key)
        defaults.synchronize()
        
    }
    
    func loadStringPref(key : String, defaultValue: String?) -> String? {
      let defaults = UserDefaults.standard
      if let value = defaults.string(forKey: key) {
            return value
        }else {
            return defaultValue
        }
    }
    
    func saveIntPref(key : String, value : Int) {
      let defaults = UserDefaults.standard
      defaults.set(value, forKey: key)
        defaults.synchronize()
        
    }
    
    func loadIntPref(key : String, defaultValue: Int) -> Int {
      let defaults = UserDefaults.standard
      if let value = defaults.object(forKey: key) as! Int? {
            return value
        }else {
            return defaultValue
        }
    }

    func saveBoolPref(key : String, value : Bool) {
      let defaults = UserDefaults.standard
        defaults.set(value, forKey: key)
        defaults.synchronize()
        
    }
    
    func loadBoolPref(key : String, defaultValue: Bool) -> Bool {
      let defaults = UserDefaults.standard
      if let value = defaults.object(forKey: key) as! Bool? {
            return value
        }else {
            return defaultValue
        }
    }
    
}
