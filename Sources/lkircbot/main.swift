import Foundation

#if os(Linux)
  import Glibc
#endif
import func Dispatch.dispatchMain
import NIO
import NIOIRC
import IRCServer
import IRCWebClient
import IRCElizaBot
import LinkerKitIRCBot
import SwiftyLinkerKit


// Commandline config
let config = Config()


// MARK: - Setup Shield

let shield = LKRBShield.default

let lkDigi    = LKDigi()
let lkButtons = LKButton2()
let lkPIR     = LKPIR()
let lkTemp    = LKTemp(interval: 60, valueType: .celsius)

shield.connect(lkDigi,    to: .digital45)
shield.connect(lkButtons, to: .digital2122)
shield.connect(lkPIR,     to: .digital1213)
shield.connect(lkTemp,    to: .analog23)


// MARK: - Setup a shared thread pool, for all services we run

let loopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)


// MARK: - Setup IRC Server

let ircConfig = IRCServer.Configuration(eventLoopGroup: loopGroup)
ircConfig.origin = config.origin ?? "localhost"
ircConfig.host   = config.ircURL?.host
ircConfig.port   = config.ircURL?.port ?? DefaultIRCPort

let ircServer = IRCServer(configuration: ircConfig)


// MARK: - Setup Web Client Server

let webConfig = IRCWebClientServer.Configuration(eventLoopGroup: loopGroup)
webConfig.host             = config.webURL?.host ?? ircConfig.host
webConfig.port             = config.webURL?.port ?? 1337
webConfig.ircHost          = ircConfig.host
webConfig.ircPort          = ircConfig.port
webConfig.externalHost     = config.extWebURL?.host ?? webConfig.host
webConfig.externalPort     = config.extWebURL?.port ?? webConfig.port
webConfig.autoJoinChannels = [ "#LinkerKit", "#NIO", "#SwiftDE" ]
webConfig.autoSendMessages = []
webConfig.autoSendMessages = [
  ( "Eliza", "Moin" )
]

let webServer = IRCWebClientServer(configuration: webConfig)


// MARK: - Run Servers

signal(SIGINT) { // Safe? Unsafe. No idea :-)
  s in ircServer.stopOnSignal(s)
}

ircServer.listen()
webServer.listen()


// MARK: - Run Bots

let elizaConfig = IRCElizaBot.Options(eventLoopGroup: loopGroup)
elizaConfig.hostname = ircConfig.host ?? "localhost"
elizaConfig.port     = ircConfig.port

let eliza = IRCElizaBot(options: elizaConfig)
eliza.connect()


let botConfig = IRCLinkerKitBot.Options(eventLoopGroup: loopGroup)
botConfig.hostname = ircConfig.host ?? "localhost"
botConfig.port     = ircConfig.port
botConfig.shield   = shield

let bot = IRCLinkerKitBot(options: botConfig)
bot.connect()


// MARK: - Runloop

#if false // produces Zombies in Xcode
  dispatchMain()
#else
  try? ircServer.serverChannel?.closeFuture.wait()
#endif
