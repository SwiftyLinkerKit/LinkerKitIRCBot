<h2>LinkerKitIRCBot
  <img src="http://zeezide.com/img/LKDigi128.png"
       align="right" width="128" height="128" />
</h2>

![Swift4](https://img.shields.io/badge/swift-4-blue.svg)
![tuxOS](https://img.shields.io/badge/os-tuxOS-green.svg?style=flat)
<a href="https://slackpass.io/swift-arm"><img src="https://img.shields.io/badge/Slack-swift/arm-red.svg?style=flat"/></a>
<a href="https://travis-ci.org/SwiftyLinkerKit/LinkerKitIRCBot"><img src="https://travis-ci.org/SwiftyLinkerKit/LinkerKitIRCBot.svg?branch=develop" /></a>

A [SwiftNIO IRC](https://github.com/NozeIO/swift-nio-irc) based bot which can
talk to 
[LinkerKit](http://www.linkerkit.de/)
components using
[SwiftyLinkerKit](https://github.com/SwiftyLinkerKit/SwiftyLinkerKit).

## Software

This Swift package contains the `LinkerKitIRCBot` as a module which can be
included into other software,
and the `lkircbot` tool, which starts up a MiniIRC server.

The `lkircbot` runs an IRC server on port 6667, and it runs a HTTP/WebSocket
server on ort 1337. 
By connecting to it using [http://zpi3.local:1337/](http://zpi3.local:1337/)
(adjust the hostname), you get a simple web IRC client included in the server.

You can either send direct messages to the bot using `/msg lkbot command`,
e.g. `/msg lkbot show clock`,
or you can use the `#linkerbot` channel, which the linkerbot watches.

When you want to run the `lkircbot`, you need to modify the source to include
your specific LinkerKit setup!

The example setup is this:

```swift
let shield = LKRBShield.default

let lkDigi    = LKDigi()
let lkButtons = LKButton2()
let lkPIR     = LKPIR()
let lkTemp    = LKTemp(interval: 60, valueType: .celsius)

shield.connect(lkDigi,    to: .digital45)
shield.connect(lkButtons, to: .digital2122)
shield.connect(lkPIR,     to: .digital1213)
shield.connect(lkTemp,    to: .analog23)
```

So we have the 7-segment LK-Digi on socket digital 4/5,
the LK-Buttons-2 on socket digital 21/22,
the LK-PIR on socket digital 12/13,
and finally the temperature sensor LK-Temp on the *analog* socket 2/3.


### Who

**LinkerKitIRCBot** is brought to you by
[AlwaysRightInstitute](http://www.alwaysrightinstitute.com).
We like feedback, GitHub stars, 
cool [contract work](http://zeezide.com/en/services/services.html),
presumably any form of praise you can think of.

There is a channel on the [Swift-ARM Slack](http://swift-arm.noze.io).
