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

let nc = NotificationCenter.defaultCenter()

_ = nc.addObserverForName(DisconnectedNotification.name, object:nil, queue:nil){_ in
  SLogInfo("Connecting to broker")

  if !client.connect() {
    SLogError("Unable to connect to broker.hivemq.com, retrying in 30 seconds")
    let retryInterval     = 30
    let retryTimer        = Timer.scheduledTimer(withTimeInterval:TimeInterval(retryInterval),
                                                 repeats:false){ _ in
      nc.postNotification(DisconnectedNotification)
    }
    RunLoop.current().add(retryTimer, forMode:RunLoopMode.defaultRunLoopMode)
  }
}

_ = nc.addObserverForName(ConnectedNotification.name, object:nil, queue:nil) {_ in
  SLogInfo("Subscribe to topic")
  _ = client.subscribe(topic:"/\(hostname)/cpu/temperature/value")
}

_ = nc.addObserverForName(MessageNotification.name, object:nil, queue:nil){ notification in
  if let userInfo = notification.userInfo,
     let message  = userInfo["message"] as? MQTTMessage {
    if let string   = message.string {
      SLogInfo("Received \(string) for topic \(message.topic)")
    }
  } else {
    SLogError("Unable to obtain MQTT message")
  }
}

nc.postNotification(DisconnectedNotification) // Kick the connection


let heartbeat = Timer.scheduledTimer(withTimeInterval:TimeInterval(30), repeats:true){_ in return}
RunLoop.current().add(heartbeat, forMode:RunLoopMode.defaultRunLoopMode)
RunLoop.current().run()

