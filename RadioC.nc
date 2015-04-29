 #include <Timer.h>
 #include "Radio.h"
 #include <time.h>
 #include "gps.h"
 
 module RadioC @safe() {
  uses {
    interface Boot;
    interface Leds;
    interface Receive;
    interface Timer<TMilli> as SensorsTimer;
    interface Timer<TMilli> as SmokeTimer;
    interface Packet;
    interface AMPacket;
    interface AMSend;
    interface SplitControl as AMControl;
    interface gps;
    interface smokeDetector;
    interface temperatureDetector;
    interface humidityDetector;
  }
 }
 implementation {
  bool busy = FALSE;
  bool smokeDetected = FALSE;
  message_t pkt;
  uint16_t counter = 0;
  position_t p;
  time_t rawtime;
  struct tm *info;
  int BST = 1;
  bool registeredNodes[65000] = { FALSE };
  int positionXSensorNodes[65000];
  int positionYSensorNodes[65000];
  int lastTimeStamp[65000];
  int lastDate[65000];
  position_t pos;

 
  event void Boot.booted() {
    call AMControl.start();
    dbg("debug", "Node booted.\n");
  }

  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      // TODO: Register with server

      if(TOS_NODE_ID >= 100){

        radio_msg* rpkt = (radio_msg*)(call Packet.getPayload(&pkt, sizeof (radio_msg)));
        rpkt->msg_type = REGISTER;        
        rpkt->nodeid = TOS_NODE_ID;
        rpkt->dest = 0;
        
        time(&rawtime);
        info = gmtime(&rawtime);
        rpkt->seconds = info->tm_sec;
        rpkt->minutes = info->tm_min;
        rpkt->hour = info->tm_hour+BST;
        rpkt->day = info->tm_mday;
        rpkt->month = info->tm_mon;
        rpkt->year = info->tm_year+1900;

        pos = call gps.getPosition();
        rpkt->x = pos.x;
        rpkt->y = pos.y;
          
        if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(radio_msg)) == SUCCESS) {
          busy = TRUE;
          dbg("debug", "< %2d:%02d:%02d %02d/%02d/%d> Register message sent with coordinates x: %d and y: %d.\n", (info->tm_hour+BST), info->tm_min, info->tm_sec, info->tm_mday, info->tm_mon+1, 1900 + info->tm_year, rpkt->x, rpkt->y);
        }
        call SensorsTimer.startPeriodic(T_MEASURE);
        call SmokeTimer.startPeriodic(T_SMOKE_MEASURE);
      }
    }
    else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
  }

  event void SmokeTimer.fired() {
    //dbg("debug", "SMOKE TIMER FIRED\n");
    if (!busy && (call smokeDetector.getSmoke() || smokeDetected)) {
      radio_msg* rpkt = (radio_msg*)(call Packet.getPayload(&pkt, sizeof (radio_msg)));
      rpkt->nodeid = TOS_NODE_ID;
      rpkt->dest = 0;
      rpkt->msg_type = SMOKE;
      rpkt->smoke = 1;

      time(&rawtime);
      info = gmtime(&rawtime);
      rpkt->seconds = info->tm_sec;
      rpkt->minutes = info->tm_min;
      rpkt->hour = info->tm_hour+BST;
      rpkt->day = info->tm_mday;
      rpkt->month = info->tm_mon;
      rpkt->year = info->tm_year+1900;

      if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(radio_msg)) == SUCCESS) {
        busy = TRUE;
        dbg("debug", "< %2d:%02d:%02d %02d/%02d/%d> SMOKE DETECTED!!!", (info->tm_hour+BST), info->tm_min, info->tm_sec, info->tm_mday, info->tm_mon+1, 1900 + info->tm_year);

      }
    }
  }
 
  event void SensorsTimer.fired() {
    //dbg("debug", "SENSOR TIMER FIRED\n");
    if (!busy) {
  		radio_msg* rpkt = (radio_msg*)(call Packet.getPayload(&pkt, sizeof (radio_msg)));
   		rpkt->nodeid = TOS_NODE_ID;
      rpkt->dest = 0;
      rpkt->msg_type = MEASURES;
      rpkt->humidity = call humidityDetector.getHumidity();
      rpkt->temperature = call temperatureDetector.getTemperature();

      time(&rawtime);
      info = gmtime(&rawtime);
      rpkt->seconds = info->tm_sec;
      rpkt->minutes = info->tm_min;
      rpkt->hour = info->tm_hour+BST;
      rpkt->day = info->tm_mday;
      rpkt->month = info->tm_mon;
      rpkt->year = info->tm_year+1900;

      if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(radio_msg)) == SUCCESS) {
        busy = TRUE;
        dbg("debug", "London : %2d:%02d:%02d %02d/%02d/%d\n", (info->tm_hour+BST), info->tm_min, info->tm_sec, info->tm_mday, info->tm_mon+1, 1900 + info->tm_year);
      }
    }
  }

  event void AMSend.sendDone(message_t* msg, error_t error) {
    if (&pkt == msg) {
      busy = FALSE;
      dbg("debug", "Busy FALSE.\n");
    }
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {


    if (len == sizeof(radio_msg)) {
      radio_msg* rpkt = (radio_msg*)payload;
      //dbg("debug", "Message Received from %d with random value %d and counter %d.\n", rpkt->nodeid, rpkt->randvalue, rpkt->counter);

      if(rpkt->msg_type == SIMULATE_FIRE){
        dbg("debug", "RECEIVED FIRE!!!!");
      }

        
        //Message REGISTER
      if(rpkt->msg_type == REGISTER){

        //SERVER
        if( TOS_NODE_ID == 0){
          //verifica se o sensorNode já se encontra registado
          if(registeredNodes[rpkt->nodeid] == FALSE){
            registeredNodes[rpkt->nodeid] = TRUE;
            positionXSensorNodes[rpkt->nodeid] = rpkt->x;
            positionYSensorNodes[rpkt->nodeid] = rpkt->y;
            dbg("debug", "[REGISTER] Sensor Node %d registered with positions x: %d and y: %d at %2d:%02d:%02d %02d/%02d/%d\n", rpkt->nodeid, rpkt->x, rpkt->y, rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year);
            dbg("log", "<%2d:%02d:%02d %02d/%02d/%d> Sensor Node %d registered with positions x: %d and y: %d.\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, rpkt->nodeid, rpkt->x, rpkt->y);
          }
        }

        //ROUTING NODES
        else if( TOS_NODE_ID <= 99 && TOS_NODE_ID >= 1){
          if(!busy){
            radio_msg* rpktR = (radio_msg*)(call Packet.getPayload(&pkt, sizeof (radio_msg)));

            rpktR->msg_type = rpkt->msg_type;        
            rpktR->nodeid = rpkt->nodeid;
            rpktR->dest = rpkt->dest;
            
            rpktR->seconds = rpkt->seconds;
            rpktR->minutes = rpkt->minutes;
            rpktR->hour = rpkt->hour;
            rpktR->day = rpkt->day;
            rpktR->month = rpkt->month;
            rpktR->year = rpkt->year;

            rpktR->x = rpkt->x;
            rpktR->y = rpkt->y;

            if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(radio_msg)) == SUCCESS) {
              busy = TRUE;
              dbg("debug", "[REGISTER] Message Sent from %d to %d (init in sensorNode %d).\n", TOS_NODE_ID, rpktR->dest, rpktR->nodeid);
            }
          }
        }
      }
      else if(rpkt->msg_type == MEASURES){

        if(TOS_NODE_ID >=0 && TOS_NODE_ID < 100){
          //verifica se o timestamp e mais recente que o da ultima mensagem recebida
          int timestampMsg = rpkt->hour*10000 + rpkt->minutes*100 + rpkt->seconds;
          int dateMsg = rpkt->year*10000 + rpkt->minutes*100 + rpkt->seconds;
          //tempo (horas) recebido e maior que o da ultima mensagem recebida
          if(timestampMsg > lastTimeStamp[rpkt->nodeid]){
            lastTimeStamp[rpkt->nodeid] = timestampMsg;
            lastDate[rpkt->nodeid] = dateMsg;
            //dbg("debug", "Sensor Node %d mesure of humidity: %d%% and temperature: %d at %2d:%02d:%02d %02d/%02d/%d\n", rpkt->nodeid, rpkt->humidity, rpkt->temperature, rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year);
            if(TOS_NODE_ID == 0)
            {
              dbg("debug", "[MEASURE] <%2d:%02d:%02d %02d/%02d/%d> Sensor Node %d measure with humidity: %d%% and temperature: %d.\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, rpkt->nodeid, rpkt->humidity, rpkt->temperature);
              dbg("log", "<%2d:%02d:%02d %02d/%02d/%d> Sensor Node %d measure with humidity: %d%% and temperature: %d.\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, rpkt->nodeid, rpkt->humidity, rpkt->temperature);
            } 
            else
            {
              if(!busy){
                radio_msg* rpktR = (radio_msg*)(call Packet.getPayload(&pkt, sizeof (radio_msg)));

                rpktR->msg_type = rpkt->msg_type;        
                rpktR->nodeid = rpkt->nodeid;
                rpktR->dest = rpkt->dest;
                
                rpktR->seconds = rpkt->seconds;
                rpktR->minutes = rpkt->minutes;
                rpktR->hour = rpkt->hour;
                rpktR->day = rpkt->day;
                rpktR->month = rpkt->month;
                rpktR->year = rpkt->year;

                rpktR->humidity = rpkt->humidity;
                rpktR->temperature = rpkt->temperature;

                if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(radio_msg)) == SUCCESS) {
                  busy = TRUE;
                  dbg("debug", "[MEASURE] Message Sent from %d to %d (init in sensorNode %d).\n", TOS_NODE_ID, rpktR->dest, rpktR->nodeid);
                }
              }
            }
          }
          //tempo (horas) recebido e menor que o da ultima mensagem
          else
          {
            //vai ver a data, se a data recebida for maior guarda esses novos valores no log
            if(dateMsg > lastDate[rpkt->nodeid]){
              lastTimeStamp[rpkt->nodeid] = timestampMsg;
              lastDate[rpkt->nodeid] = dateMsg;
              //dbg("debug", "Sensor Node %d mesure of humidity: %d%% and temperature: %d at %2d:%02d:%02d %02d/%02d/%d\n", rpkt->nodeid, rpkt->humidity, rpkt->temperature, rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year);
              if(TOS_NODE_ID == 0)
              {
                dbg("debug", "[MEASURE] <%2d:%02d:%02d %02d/%02d/%d> Sensor Node %d measure with humidity: %d%% and temperature: %d.\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, rpkt->nodeid, rpkt->humidity, rpkt->temperature);
                dbg("log", "<%2d:%02d:%02d %02d/%02d/%d> Sensor Node %d measure with humidity: %d%% and temperature: %d.\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, rpkt->nodeid, rpkt->humidity, rpkt->temperature);
              }
              else
              {
                if(!busy){
                  radio_msg* rpktR = (radio_msg*)(call Packet.getPayload(&pkt, sizeof (radio_msg)));

                  rpktR->msg_type = rpkt->msg_type;        
                  rpktR->nodeid = rpkt->nodeid;
                  rpktR->dest = rpkt->dest;
                  
                  rpktR->seconds = rpkt->seconds;
                  rpktR->minutes = rpkt->minutes;
                  rpktR->hour = rpkt->hour;
                  rpktR->day = rpkt->day;
                  rpktR->month = rpkt->month;
                  rpktR->year = rpkt->year;

                  rpktR->humidity = rpkt->humidity;
                  rpktR->temperature = rpkt->temperature;

                  if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(radio_msg)) == SUCCESS) {
                    busy = TRUE;
                    dbg("debug", "[MEASURE] Message Sent from %d to %d (init in sensorNode %d).\n", TOS_NODE_ID, rpktR->dest, rpktR->nodeid);
                  }
                }
              }
            }
          }
        }
      }

    }
    return msg;

    //antes
    /*
    if (len == sizeof(radio_msg)) {
      radio_msg* rpkt = (radio_msg*)payload;
      dbg("debug", "Message Received from %d with random value %d and counter %d.\n", rpkt->nodeid, rpkt->randvalue, rpkt->counter);
      if(!busy){
        radio_msg* rpktR = (radio_msg*)(call Packet.getPayload(&pkt, sizeof (radio_msg)));
          rpktR->nodeid = rpkt->nodeid;
          rpktR->counter = rpkt->counter;
          rpktR->randvalue = rpkt->randvalue;
        if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(radio_msg)) == SUCCESS) {
          busy = TRUE;
          dbg("debug", "Message Sent from %d with counter %d.\n", TOS_NODE_ID, rpktR->counter);
        }
      }

    }
    return msg;
    */
    //antes
  }

}
