 #include <Timer.h>
 #include "Radio.h"
 
 configuration RadioAppC {
 }
 implementation {
   components MainC;
   components LedsC;
   components RadioC as App;
   components new TimerMilliC() as SensorTimer;
   components ActiveMessageC;
   components new AMSenderC(AM_RADIO);
   components new AMReceiverC(AM_RADIO);
   components gpsC as GPS;
 
   App.Boot -> MainC;
   App.Leds -> LedsC;
   App.SensorTimer -> SensorTimer;
   App.Packet -> AMSenderC;
   App.AMPacket -> AMSenderC;
   App.AMSend -> AMSenderC;
   App.AMControl -> ActiveMessageC;
   App.Receive -> AMReceiverC;
 }
