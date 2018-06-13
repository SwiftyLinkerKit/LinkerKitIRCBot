//
//  LKRBShield.swift
//  SwiftyLinkerKit
//
//  Created by Helge Hess on 08.06.18.
//

import struct Foundation.TimeInterval
import struct Foundation.Date
import NIO
import IRC
import SwiftyLinkerKit

public let defaultNickName = IRCNickName("LKBot")!

open class IRCLinkerKitBot : IRCClientDelegate {
  
  open class Options : IRCClientOptions {
    
    open var shield : SwiftyLinkerKit.LKRBShield = .default
    
    override public init(port           : Int             = DefaultIRCPort,
                         host           : String          = "localhost",
                         password       : String?         = nil,
                         nickname       : IRCNickName     = defaultNickName,
                         userInfo       : IRCUserInfo?    = nil,
                         eventLoopGroup : EventLoopGroup? = nil)
    {
      super.init(port: port, host: host, password: password,
                 nickname: nickname, userInfo: userInfo,
                 eventLoopGroup: eventLoopGroup)
    }
  }
  
  public let ircClient : IRCClient
  public let shield    : SwiftyLinkerKit.LKRBShield
  public var eventLoop : EventLoop { return ircClient.eventLoop }

  public private(set) var nick : IRCNickName
  
  public init(options: Options = Options()) {
    self.shield    = options.shield
    self.nick      = options.nickname
    self.ircClient = IRCClient(options: options)
    self.ircClient.delegate = self
    
    shield.getAccessories { accessories in
      for accessory in accessories.values {
        self.registerWithAccessory(accessory)
      }
    }
  }
  
  open func connect() {
    ircClient.connect()
  }
  
  enum ClockMode {
    case off
    case clock
    case countdown(value: Int)
    case timer(value: Int, target: Int)
  }
  var clockMode : ClockMode = .off
  
  func processClock() {
    switch clockMode {
      case .off:
        return
      
      case .clock:
        print("show time")
        digi?.showTime()
      
      case .countdown(let value):
        print("countdown:", value)
        if value > 0 {
          digi?.show(value)
          clockMode = .countdown(value: value - 1)
        }
        else {
          digi?.show("XX", align: .center)
          clockMode = .off
        }
      
      case .timer(let value, let target):
        print("timer:", value, "till:", target)
        if value >= target {
          digi?.show("X\(target)", align: .center)
          clockMode = .off
        }
        else {
          digi?.show(value)
          clockMode = .timer(value: value + 1, target: target)
        }
    }
  
    if case .off = clockMode { return }
    
    _ = eventLoop.scheduleTask(in: .seconds(1)) { [weak self] in
      self?.processClock()
    }
  }
  
  var digi : LKDigi?
  
  func onMotion(_ didDetectMotion: Bool, accessory: LKPIR) { // Q: eventloop
    let message = didDetectMotion
                ? "Tracked person started to work."
                : "Tracked person stopped working."
    let target = IRCMessageRecipient.channel(linkerKitChannel)
    
    ircClient.sendMessage(message + " (PIR: \(accessory))", to: target)
  }
  
  func onButton(_ flag: Bool, button: Int, accessory: LKButton2) {
    let message = flag
                ? "Button \(button) was pressed."
                : "Button \(button) was released."
    let target = IRCMessageRecipient.channel(linkerKitChannel)
    
    ircClient.sendMessage(message + " (Buttons: \(accessory))", to: target)
  }
  
  func onTemperature(_ value: Double, accessory: LKTemp) {
    let message = "The temperature is now at \(Int(value)) \(accessory.valueType)"
    let target = IRCMessageRecipient.channel(linkerKitChannel)
    
    ircClient.sendMessage(message + " (sensor: \(accessory))", to: target)
  }
  
  
  open func registerWithAccessory(_ accessory: LKAccessory) {
    switch accessory {
      
      case let accessory as LKPIR:
        print("register PIR:", accessory)
        accessory.onChange { [weak self, weak accessory] motion in
          guard let me = self, let accessory = accessory else { return }
          me.onMotion(motion, accessory: accessory)
        }
      
      case let accessory as LKButton2:
        print("register buttons:", accessory)
        accessory.onChange1 { [weak self, weak accessory] v in
          guard let me = self, let accessory = accessory else { return }
          me.onButton(v, button: 1, accessory: accessory)
        }
        accessory.onChange2 { [weak self, weak accessory] v in
          guard let me = self, let accessory = accessory else { return }
          me.onButton(v, button: 2, accessory: accessory)
        }

      case let accessory as LKDigi:
        if let digi = digi {
          print("already registered another display:", digi)
        }
        else {
          print("register display:", accessory)
          eventLoop.execute {
            if self.digi == nil { self.digi = accessory }
          }
        }
      
      case let accessory as LKTemp:
        print("register thermometer:", accessory)
        accessory.onChange { [weak self, weak accessory] value in
          guard let me = self, let accessory = accessory else { return }
          me.onTemperature(value, accessory: accessory)
        }
      
      default:
        break
    }
  }
  
  
  // MARK: - Events
  
  func userJoinedChannel(_ user: IRCUserID) {
    let client = ircClient
    let target = IRCMessageRecipient.channel(linkerKitChannel)
    
    client.sendMessage("Welcome \(user.nick) to LinkerKit!",
                       to: target)

    let prefix = "The shield is currently connected to "
    
    shield.getAccessories { accessories in
      if accessories.isEmpty {
        let ms = prefix + "no accessories."
        client.sendMessage(ms, to: target)
      }
      else {
        let ms = prefix + "#\(accessories.count) accessories: "
               + accessories.values.map { String(describing: $0) }
                                   .joined(separator: ", ")
        client.sendMessage(ms, to: target)
      }
    }
  }
  
  // Our super-advanced NLS
  func userSentMessage(_ message: String,
                       from user: IRCUserID, to recipient: IRCMessageRecipient)
  {
    let client = ircClient
    let words  = message.components(separatedBy: .whitespacesAndNewlines)
    let match  = Set(words.map { $0.lowercased() })
    
    func reply(_ s: String) {
      if case .channel = recipient {
        ircClient.sendMessage(s, to: recipient)
      }
      else {
        let to = IRCMessageRecipient.nickname(user.nick)
        ircClient.sendMessage(s, to: to)
      }
    }
    
    print("handle message:", message)
    
    if match.contains("temperature") ||
       match.contains("cold") || match.contains("warm")
    {
      shield.getAccessories { accessories in
        var found = false
        for a in accessories.values {
          guard let temp = a as? LKTemp else { continue }
          
          if let v = temp.readValue() {
            found = true
            reply("temperature is \(v)")
          }
          else {
            reply("could not read temperature from: \(temp)")
          }
        }
        if !found { reply("No thermometer is registered!") }
      }
      return
    }
    
    if let digi = digi {
      if match.contains("timer") {
        if case .timer = clockMode, match.contains("cancel") {
          clockMode = .off
          return reply("canceled timer!")
        }
        else if match.contains("start") {
          clockMode = .timer(value: 0, target: 1337)
          processClock()
          return reply("started timer ...")
        }
      }
      
      if match.contains("countdown") {
        if case .countdown = clockMode, match.contains("cancel") {
          clockMode = .off
          return reply("canceled countdown!")
        }
        
        if let idx = words.index(where: { $0.lowercased() == "countdown" }) {
          for word in words[idx..<words.endIndex] {
            guard let i = Int(word), i > 0 else { continue }
            
            clockMode = .countdown(value: i)
            processClock()
            return reply("started countdown from \(i) ...")
          }
          clockMode = .countdown(value: 10)
          processClock()
          return reply("started countdown ...")
        }
      }
      
      if match.contains("time") || match.contains("clock") {
        if match.contains("hide") || match.contains("off") {
          clockMode = .off
          digi.turnOff()
          return reply("hiding clock.")
        }
        
        clockMode = .clock
        processClock()
        return reply("starting to show clock!")
      }
      
      if match.contains("show") {
        if let idx = words.index(where: { $0.lowercased() == "show" }),
           words.index(after: idx) < words.endIndex
        {
          let text = words[words.index(after: idx)]
          clockMode = .off
          digi.show(text)
          return reply("did show: \"\(text)\"")
        }
      }
    }
    
    let commands = [
      "show time/clock",
      "hide time",
      "clock off",
      "start timer",
      "cancel timer",
      "start countdown from 20",
      "cancel countdown"
    ]
    let s = commands.map { "'" + $0 + "'" }.joined(separator: ", ")
    reply("Messages LKBot understands: " + s)
  }
  
  
  // MARK: - IRC message handling

  open func client(_ client: IRCClient,
                   message: String, from user: IRCUserID,
                   for recipients: [ IRCMessageRecipient ])
  {
    let channelTarget = IRCMessageRecipient.channel(linkerKitChannel)
    let nickTarget    = IRCMessageRecipient.nickname(nick)
    let target        : IRCMessageRecipient
    
    if recipients.contains(channelTarget) {
      target = channelTarget
    }
    else if recipients.contains(nickTarget) {
      target = nickTarget
    }
    else {
      print("LKBot(\(nick.stringValue)): received message for different nick:",
            recipients.map { $0.stringValue })
      return
    }
    
    userSentMessage(message, from: user, to: target)
  }
  
  
  // MARK: - Nick tracking
  
  let linkerKitChannel = IRCChannelName("#LinkerKit")!

  open func client(_ client        : IRCClient,
                   registered nick : IRCNickName,
                   with   userInfo : IRCUserInfo)
  {
    self.nick = nick
    print("LKBot is ready and listening!", nick)
    
    client.send(.JOIN(channels: [ linkerKitChannel ], keys: nil))
  }
  open func client(_ client: IRCClient, changedNickTo nick: IRCNickName) {
    self.nick = nick
  }

  open func clientFailedToRegister(_ client: IRCClient) {
    print("LKBot failed to register!")
  }

  open func client(_ client: IRCClient, user: IRCUserID,
                   joined channels: [ IRCChannelName ])
  {
    if user.nick == nick {
      print("LKBot", user, "joined:",
            channels.map { $0.stringValue }.joined(separator: ", "))
    }
    else {
      print("LKBot: A user", user, "joined:",
            channels.map { $0.stringValue }.joined(separator: ", "))
      if channels.contains(linkerKitChannel) {
        userJoinedChannel(user)
      }
    }
  }
}
