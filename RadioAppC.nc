 #include <Timer.h>
 #include "Radio.h"
 
 configuration RadioAppC {
 }
 implementation {
   //components MainC;
   components LedsC;
   components MainC, RadioC as App;
   components new TimerMilliC() as Timer1;
   components new TimerMilliC() as Timer0;
   components ActiveMessageC;
   components new AMSenderC(AM_RADIO_MSG);
   components new AMReceiverC(AM_RADIO_MSG);
   components gpsC as GPS;
   components smokeDetectorC as SmokeDetector;
   components temperatureDetectorC as TemperatureDetector;
   components humidityDetectorC as HumidityDetector;
 
   App.Boot -> MainC;
   App.Leds -> LedsC;
   App.Timer1 -> Timer1;
   App.Timer0 -> Timer0;
   App.Packet -> AMSenderC;
   App.AMPacket -> AMSenderC;
   App.AMSend -> AMSenderC;
   App.AMControl -> ActiveMessageC;
   App.Receive -> AMReceiverC;
   App.gps -> GPS;
   App.smokeDetector -> SmokeDetector;
   App.temperatureDetector -> TemperatureDetector;
   App.humidityDetector -> HumidityDetector;
 }
