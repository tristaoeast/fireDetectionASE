 #include <Timer.h>
 #include "Radio.h"
 
 configuration RadioAppC {
 }
 implementation {
   components MainC;
   components LedsC;
   components RadioC as App;
   components new TimerMilliC() as SensorsTimer;
   components new TimerMilliC() as SmokeTimer;
   components ActiveMessageC;
   components new AMSenderC(AM_RADIO);
   components new AMReceiverC(AM_RADIO);
   components gpsC as GPS;
   components smokeDetectorC as SmokeDetector;
 
   App.Boot -> MainC;
   App.Leds -> LedsC;
   App.SensorsTimer -> SensorsTimer;
   App.SmokeTimer -> SmokeTimer;
   App.Packet -> AMSenderC;
   App.AMPacket -> AMSenderC;
   App.AMSend -> AMSenderC;
   App.AMControl -> ActiveMessageC;
   App.Receive -> AMReceiverC;
   App.gps -> GPS;
   App.smokeDetector -> SmokeDetector;
 }
