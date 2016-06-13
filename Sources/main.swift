//
// Copyright 2016 iAchieved.it LLC
//
// MIT License (https://opensource.org/licenses/MIT)
//

import swiftlog
import Glibc
import Foundation
import MQTT

slogLevel = .Info // Change to .Verbose to get real chatty

slogToFile(atPath:"/tmp/MQTTSub.log")

let BUFSIZE = 128
var buffer  = [CChar](repeating:0, count:BUFSIZE)
guard gethostname(&buffer, BUFSIZE) == 0 else {
  SLogError("Unable to obtain hostname")
  exit(-1)
}

let hostname = String(cString:buffer)
let clientId = hostname + "-sub"

let client = Client(clientId:clientId)
client.host = "broker.hivemq.com"
client.keepAlive = 10

let nc = NSNotificationCenter.defaultCenter()

_ = nc.addObserverForName("DisconnectedNotification", object:nil, queue:nil){_ in
  SLogInfo("Connecting to broker")

  if !client.connect() {
    SLogError("Unable to connect to broker.hivemq.com, retrying in 30 seconds")
    let retryInterval     = 30
    let retryTimer        = NSTimer.scheduledTimer(NSTimeInterval(retryInterval),
                                                   repeats:false){ _ in
      nc.postNotificationName("DisconnectedNotification", object:nil)
    }
    NSRunLoop.currentRunLoop().addTimer(retryTimer, forMode:NSDefaultRunLoopMode)
  }
}

_ = nc.addObserverForName("ConnectedNotification", object:nil, queue:nil) {_ in
  SLogInfo("Subscribe to topic")
  _ = client.subscribe(topic:"/\(hostname)/cpu/temperature/value")
}

_ = nc.addObserverForName("MessageNotification", object:nil, queue:nil){ notification in
  if let userInfo = notification.userInfo,
     let message  = userInfo["message" as NSString] as? MQTTMessage {
    if let string   = message.string {
      SLogInfo("Received \(string) for topic \(message.topic)")
    }
  } else {
    SLogError("Unable to obtain MQTT message")
  }
}

nc.postNotificationName("DisconnectedNotification", object:nil) // Kick the connection


let heartbeat = NSTimer.scheduledTimer(NSTimeInterval(30), repeats:true){_ in return}
NSRunLoop.currentRunLoop().addTimer(heartbeat, forMode:NSDefaultRunLoopMode)
NSRunLoop.currentRunLoop().run()

