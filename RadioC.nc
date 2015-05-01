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
  // GLOBAL VARS
  bool busy = FALSE;
  message_t pkt;
  message_t pktQ;
  position_t p;
  time_t rawtime;
  struct tm *info;
  int BST = 1;

  int lastRegisterTS = 0;
  int lastRegisterD = 0;

  //SENSOR NODES VARS
  bool smokeDetected = FALSE;
  bool smokeMalfunction = FALSE;
  bool gpsMalfunction = FALSE;
  bool temperatureMalfunction = FALSE;
  bool humidityMalfunction = FALSE;
  bool registered = FALSE;


  int lastMeasureTS[10000] = {0};
  int lastMeasureD[10000] = {0};

  int registeredNodes[10000] = { FALSE };
  int positionXSensorNodes[10000];
  int positionYSensorNodes[10000];
  int lastTimeStamp[10000] = {0};
  int lastAssignTimeStamp[10000] = {0};
  int lastDate[10000] = {0};
  int lastAssignDate[10000] = {0};
  int lastTimeStampRegister[10000] = {0};
  int lastDateRegister[10000] = {0};
  int mySensorNodes[100] = {0};
  int sensorNodeCounter = 0;
  int lastAckDate = 0;
  int lastAckTimeStamp = 0;
  position_t pos;
  radio_msg msg_q[10000];
  int msg_q_cnt = 0;

 
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

        rpkt->counter = 0;

        pos = call gps.getPosition();
        rpkt->x = pos.x;
        rpkt->y = pos.y;
          
        if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(radio_msg)) == SUCCESS) {
          busy = TRUE;
          dbg("debug", "< %2d:%02d:%02d %02d/%02d/%d> Register message sent with coordinates x: %d and y: %d.\n", (info->tm_hour+BST), info->tm_min, info->tm_sec, info->tm_mday, info->tm_mon+1, 1900 + info->tm_year, rpkt->x, rpkt->y);
        }
        //call SensorsTimer.startPeriodic(T_MEASURE);
        call SmokeTimer.startPeriodic(T_SMOKE_MEASURE);
      }
      else if(0 == TOS_NODE_ID){
        call SmokeTimer.startPeriodic(T_ALIVE_MEASURE);
      }
     /* else if(0 < TOS_NODE_ID && TOS_NODE_ID < 100) {
        msg_q = (radio_msg*) malloc(sizeof(radio_msg) * 10000);
      }*/
    }
    else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
  }

  event void SmokeTimer.fired() {
    //dbg("debug", "****************** SMOKE TIMER FIRED ******************\n");
    if(TOS_NODE_ID >= 100){
      if(registered){
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
            dbg("debug", "< %2d:%02d:%02d %02d/%02d/%d> SMOKE DETECTED!!!\n", (info->tm_hour+BST), info->tm_min, info->tm_sec, info->tm_mday, info->tm_mon+1, 1900 + info->tm_year);

          }
        }
      } else {
        if(!busy){
          radio_msg* rpkt = (radio_msg*)(call Packet.getPayload(&pkt, sizeof (radio_msg)));
          call SmokeTimer.stop();
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

          rpkt->counter = 0;

          pos = call gps.getPosition();
          rpkt->x = pos.x;
          rpkt->y = pos.y;
            
          if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(radio_msg)) == SUCCESS) {
            busy = TRUE;
            dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> Register message sent with coordinates x: %d and y: %d.\n", (info->tm_hour+BST), info->tm_min, info->tm_sec, info->tm_mday, info->tm_mon+1, 1900 + info->tm_year, rpkt->x, rpkt->y);
          }
        }
        call SmokeTimer.startPeriodic(T_SMOKE_MEASURE);
      }
    } 
    else if (0 == TOS_NODE_ID){
      int i;
      int ts;
      time(&rawtime);
      info = gmtime(&rawtime);
      ts = (info->tm_hour+BST)*10000 + info->tm_min*100 + info->tm_sec;
      for(i = 100; i < sensorNodeCounter; i++){
        int etime = ts - lastMeasureTS[i];
        if(etime < -500 || etime > 500){
          //TODO: SEND A RE REGISTER MESSAGE
          if(!busy){
            radio_msg* rpkt = (radio_msg*)(call Packet.getPayload(&pkt, sizeof (radio_msg)));
            call SmokeTimer.stop();
            rpkt->msg_type = RE_REGISTER;        
            rpkt->dest = i;
            
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
              dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> Re-Register message sent to sensor node: %d.\n", (info->tm_hour+BST), info->tm_min, info->tm_sec, info->tm_mday, info->tm_mon+1, 1900 + info->tm_year, i);
            }
          }
        }
      }
    }
    else {
      dbg("debug", "############### IM ALIVE ############### MSG_Q_CNT: %d\n", msg_q_cnt);
      call SmokeTimer.stop();
    }
  }
 
  event void SensorsTimer.fired() {
    //dbg("debug", "SENSOR TIMER FIRED\n");
    if (!busy) {
  		radio_msg* rpkt = (radio_msg*)(call Packet.getPayload(&pkt, sizeof (radio_msg)));
   		rpkt->nodeid = TOS_NODE_ID;
      rpkt->dest = 0;
      rpkt->msg_type = MEASURES;
      if(gpsMalfunction){
        rpkt->x = -1;
        rpkt->y = -1;
      }
      else {
        position_t pt = call gps.getPosition();
        rpkt->x = pt.x;
        rpkt->y = pt.y;
      }
      if(humidityMalfunction) {
        rpkt->humidity = -1;
      }
      else {
        rpkt->humidity = call humidityDetector.getHumidity();
      }      
      if(temperatureMalfunction) {
        rpkt->temperature = -1;
      }
      else {
        rpkt->temperature = call temperatureDetector.getTemperature();
      }      
      if(smokeMalfunction) {
        rpkt->smoke = -1;
      }
      else if(smokeDetected) {
        rpkt->smoke = 1;
      } 
      else {
        rpkt->smoke = 0;
      }
      rpkt->counter = 0;

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
        dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> Sent measurements\n", (info->tm_hour+BST), info->tm_min, info->tm_sec, info->tm_mday, info->tm_mon+1, 1900 + info->tm_year);
      }
    }
  }

  event void AMSend.sendDone(message_t* msg, error_t error) {
    if ((&pkt == msg) || (&pktQ == msg)) {
      busy = FALSE;     
      //dbg("debug", "[SEND_DONE].\n");
      if(!busy && msg_q_cnt > 0) {
        int ind = msg_q_cnt - 1;
        radio_msg* rpkt = (radio_msg*)(call Packet.getPayload(&pkt, sizeof (radio_msg)));
        dbg("debug", "[SEND DONE -> QUEUE] Number of messages in queue: %d\n", msg_q_cnt);
        //dbg("debug", "[SEND_DONE] 1\n");
        rpkt->msg_type = msg_q[ind].msg_type;
        //dbg("debug", "[SEND_DONE] 2\n");
        rpkt->nodeid = msg_q[ind].nodeid;
        //dbg("debug", "[SEND_DONE] 3\n");
        rpkt->dest = msg_q[ind].dest;
        //dbg("debug", "[SEND_DONE] 4\n");
        rpkt->counter = msg_q[ind].counter;
        //dbg("debug", "[SEND_DONE] 5\n");
        rpkt->randvalue = msg_q[ind].randvalue;
        //dbg("debug", "[SEND_DONE] 6\n");
        rpkt->routingNode = msg_q[ind].routingNode;
        //dbg("debug", "[SEND_DONE] 7\n");
        rpkt->seconds = msg_q[ind].seconds;
        //dbg("debug", "[SEND_DONE] 8\n");
        rpkt->minutes = msg_q[ind].minutes;
        //dbg("debug", "[SEND_DONE] 9\n");
        rpkt->hour = msg_q[ind].hour;
        //dbg("debug", "[SEND_DONE] 10\n");
        rpkt->day = msg_q[ind].day;
        //dbg("debug", "[SEND_DONE] 11\n");
        rpkt->month = msg_q[ind].month;
        //dbg("debug", "[SEND_DONE] 12\n");
        rpkt->year = msg_q[ind].year;
        //dbg("debug", "[SEND_DONE] 13\n");
        rpkt->x = msg_q[ind].x;
        //dbg("debug", "[SEND_DONE] 14\n");
        rpkt->y = msg_q[ind].y;
        //dbg("debug", "[SEND_DONE] 15\n");        
        rpkt->humidity = msg_q[ind].humidity;
        //dbg("debug", "[SEND_DONE] 16\n");
        rpkt->temperature = msg_q[ind].temperature;
        //dbg("debug", "[SEND_DONE] 17\n");
        rpkt->smoke = msg_q[ind].smoke;
        //dbg("debug", "[SEND_DONE] 18\n");
        msg_q_cnt--;
        //dbg("debug", "[SEND_DONE] 19\n");

        //dbg("debug", "[SEND_DONE] QUEUE HAS MESSAGES\n");

        if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(radio_msg)) == SUCCESS) {
          busy = TRUE;
          dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [SEND DONE -> QUEUE] MESSAGE QUEUE SENT *****TYPE***** : %d  *****DEST***** : %d\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, rpkt->msg_type, rpkt->dest);
          //dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [SEND_DONE] Message sent from queue\n", (info->tm_hour+BST), info->tm_min, info->tm_sec, info->tm_mday, info->tm_mon+1, 1900 + info->tm_year);
        }
      }
    }
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {

    //dbg("debug", "[MSG RECEIVED] INIT\n");
    if (len == sizeof(radio_msg)) {
      radio_msg* rpkt = (radio_msg*)payload;
      //dbg("debug", "[MSG RECEIVED] msg_type: %d\n", rpkt->msg_type);

      if(rpkt->msg_type == RE_REGISTER && TOS_NODE_ID == rpkt->dest){
        //verifica se o timestamp e mais recente que o da ultima mensagem recebida
        int timestampMsg = rpkt->hour*10000 + rpkt->minutes*100 + rpkt->seconds;
        int dateMsg = rpkt->year*10000 + rpkt->month*100 + rpkt->day;
        //tempo (horas) recebido e maior que o da ultima mensagem recebida
        if((timestampMsg > lastAckTimeStamp) || (dateMsg > lastAckDate)) {
          registered = FALSE;
          ("debug", "<%2d:%02d:%02d %02d/%02d/%d> [RE_REGISTER] \n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year);
        }
      }
      else if(rpkt->msg_type == ASSIGN_SNODE){
        //dbg("debug", "[RECEIVED ASSIGN MODE]\n");
        if(TOS_NODE_ID <= 99 && TOS_NODE_ID >= 1){
          //verifica se o timestamp e mais recente que o da ultima mensagem recebida
          int timestampMsg = rpkt->hour*10000 + rpkt->minutes*100 + rpkt->seconds;
          int dateMsg = rpkt->year*10000 + rpkt->month*100 + rpkt->day;
          //tempo (horas) recebido e maior que o da ultima mensagem recebida
          if((timestampMsg > lastAssignTimeStamp[rpkt->nodeid]) || (dateMsg > lastAssignDate[rpkt->nodeid])) {
            lastAssignTimeStamp[rpkt->nodeid] = timestampMsg;
            lastAssignDate[rpkt->nodeid] = dateMsg;
            if(rpkt->dest == TOS_NODE_ID && sensorNodeCounter < 100)
            {
              int i;
              bool mine = FALSE;
              int id = rpkt->nodeid;
              for(i=0; i<100; i++){
                if(mySensorNodes[i] == id){
                  mine = TRUE;
                  break;
                }
              }
              if(!mine) 
              {
                mySensorNodes[sensorNodeCounter] = rpkt->nodeid;
                sensorNodeCounter++;
                dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [ASSIGN_SNODE] Sensor Node %d assgined to Routing Node %d.\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, rpkt->nodeid, TOS_NODE_ID);
                // retransmit assign message to sensor node as an ack
                if (!busy) {
                  radio_msg* rpktR = (radio_msg*)(call Packet.getPayload(&pkt, sizeof (radio_msg)));
                  rpktR->nodeid = rpkt->nodeid;
                  rpktR->dest = rpkt->dest;
                  rpktR->msg_type = rpkt->msg_type;
                  rpktR->routingNode = rpkt->dest;

                  rpktR->seconds = rpkt->seconds;
                  rpktR->minutes = rpkt->minutes;
                  rpktR->hour = rpkt->hour;
                  rpktR->day = rpkt->day;
                  rpktR->month = rpkt->month;
                  rpktR->year = rpkt->year;
                  
                  if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(radio_msg)) == SUCCESS) {
                    busy = TRUE;
                    dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [ASSIGN_SNODE RETRANSMITTED TO SN] Sensor Node %d assgined to Routing Node %d.\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year,  rpkt->nodeid, rpkt->dest);
                  }
                }
                else {
                  msg_q[msg_q_cnt].nodeid = rpkt->nodeid;
                  msg_q[msg_q_cnt].dest = rpkt->dest;
                  msg_q[msg_q_cnt].msg_type = rpkt->msg_type;

                    //REGISTER vars
                  msg_q[msg_q_cnt].counter=0;
                  msg_q[msg_q_cnt].randvalue=0;
                  msg_q[msg_q_cnt].routingNode=0;

                  // Timestamp
                  time(&rawtime);
                  info = gmtime(&rawtime);
                  msg_q[msg_q_cnt].seconds = info->tm_sec;
                  msg_q[msg_q_cnt].minutes = info->tm_min;
                  msg_q[msg_q_cnt].hour = info->tm_hour+BST;
                  msg_q[msg_q_cnt].day = info->tm_mday;
                  msg_q[msg_q_cnt].month = info->tm_mon;
                  msg_q[msg_q_cnt].year = info->tm_year+1900;

                  // GPS coordinates
                  msg_q[msg_q_cnt].x=0;
                  msg_q[msg_q_cnt].y=0;

                  // Humidity information
                  msg_q[msg_q_cnt].humidity=0;

                  // Temperature information
                  msg_q[msg_q_cnt].temperature=0;

                  // Smoke information
                  msg_q[msg_q_cnt].smoke=0;

                  msg_q_cnt++;
                  dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [ASSIGN_SNODE -> QUEUE] Radio buffer busy. Moving message to queue.\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year);
                }
              }
            }
            else{
              // retransmit message if isnt the assigned routing node
              if (!busy) {
                radio_msg* rpktR = (radio_msg*)(call Packet.getPayload(&pkt, sizeof (radio_msg)));
                rpktR->nodeid = rpkt->nodeid;
                rpktR->dest = rpkt->dest;
                rpktR->msg_type = rpkt->msg_type;

                rpktR->seconds = rpkt->seconds;
                rpktR->minutes = rpkt->minutes;
                rpktR->hour = rpkt->hour;
                rpktR->day = rpkt->day;
                rpktR->month = rpkt->month;
                rpktR->year = rpkt->year;
                
                if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(radio_msg)) == SUCCESS) {
                  busy = TRUE;
                  dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [ASSIGN_SNODE RETRANSMITTED] Sensor Node %d assgined to Routing Node %d.\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year,  rpkt->nodeid, rpkt->dest);
                }
              }
              else {
                msg_q[msg_q_cnt].nodeid = rpkt->nodeid;
                msg_q[msg_q_cnt].dest = rpkt->dest;
                msg_q[msg_q_cnt].msg_type = rpkt->msg_type;

                  //REGISTER vars
                msg_q[msg_q_cnt].counter=0;
                msg_q[msg_q_cnt].randvalue=0;
                msg_q[msg_q_cnt].routingNode=0;

                // Timestamp
                time(&rawtime);
                info = gmtime(&rawtime);
                msg_q[msg_q_cnt].seconds = info->tm_sec;
                msg_q[msg_q_cnt].minutes = info->tm_min;
                msg_q[msg_q_cnt].hour = info->tm_hour+BST;
                msg_q[msg_q_cnt].day = info->tm_mday;
                msg_q[msg_q_cnt].month = info->tm_mon;
                msg_q[msg_q_cnt].year = info->tm_year+1900;

                // GPS coordinates
                msg_q[msg_q_cnt].x=0;
                msg_q[msg_q_cnt].y=0;

                // Humidity information
                msg_q[msg_q_cnt].humidity=0;

                // Temperature information
                msg_q[msg_q_cnt].temperature=0;

                // Smoke information
                msg_q[msg_q_cnt].smoke=0;

                msg_q_cnt++;
                dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [ASSIGN_SNODE -> QUEUE] Radio buffer busy. Moving message to queue.\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year);
              }
            }
          }
        }
        else if(TOS_NODE_ID >= 100 && rpkt->nodeid == TOS_NODE_ID && rpkt->routingNode != 0){
          //verifica se o timestamp e mais recente que o da ultima mensagem recebida
          int timestampMsg = rpkt->hour*10000 + rpkt->minutes*100 + rpkt->seconds;
          int dateMsg = rpkt->year*10000 + rpkt->month*100 + rpkt->day;
          //tempo (horas) recebido e maior que o da ultima mensagem recebida
          if((timestampMsg > lastAckTimeStamp) || (dateMsg > lastAckDate)) {
            lastAckTimeStamp = timestampMsg;
            lastAckDate = dateMsg;

            dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [ASSIGN_SNODE -> SENSOR NODE] Assign ack. Starting timers.\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year);
            registered = TRUE;
            call SmokeTimer.startPeriodic(T_SMOKE_MEASURE);
            call SensorsTimer.startPeriodic(T_MEASURE);
          }
        }
      }
      else if(rpkt->msg_type == SIMULATE_FIRE){
        //dbg("debug", "RECEIVED FIRE!!!!\n");
        smokeDetected = TRUE;
        if (!busy) {
          radio_msg* rpktR = (radio_msg*)(call Packet.getPayload(&pkt, sizeof (radio_msg)));
          rpktR->nodeid = TOS_NODE_ID;
          rpktR->dest = 0;
          rpktR->msg_type = SMOKE;
          rpktR->smoke = 1;

          time(&rawtime);
          info = gmtime(&rawtime);
          rpktR->seconds = info->tm_sec;
          rpktR->minutes = info->tm_min;
          rpktR->hour = info->tm_hour+BST;
          rpktR->day = info->tm_mday;
          rpktR->month = info->tm_mon;
          rpktR->year = info->tm_year+1900;

          if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(radio_msg)) == SUCCESS) {
            busy = TRUE;
            dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> SMOKE DETECTED!!!\n", (info->tm_hour+BST), info->tm_min, info->tm_sec, info->tm_mday, info->tm_mon+1, 1900 + info->tm_year);
          }
        }
      } 
      else if(rpkt->msg_type == PUT_OUT_FIRE){
        dbg("debug", "THE FIREMEN CAME AND PUT OUT THE FIRE!!!!!!!!!!!!\n");
        smokeDetected = FALSE;
      }
      else if(rpkt->msg_type == SIMULATE_SMOKE_MALFUNCTION){
        dbg("debug", "SMOKE MODULE MALFUNCTION\n");
        smokeMalfunction = TRUE;
      }      
      else if(rpkt->msg_type == SIMULATE_GPS_MALFUNCTION){
        dbg("debug", "GPS MODULE MALFUNCTION\n");
        gpsMalfunction = TRUE;
      }
      else if(rpkt->msg_type == SIMULATE_TEMPERATURE_MALFUNCTION){
        dbg("debug", "TEMPERATURE MODULE MALFUNCTION\n");
        temperatureMalfunction = TRUE;
      }      
      else if(rpkt->msg_type == SIMULATE_HUMIDITY_MALFUNCTION){
        dbg("debug", "HUMIDITY MODULE MALFUNCTION\n");
        humidityMalfunction = TRUE;
      }      
      else if(rpkt->msg_type == SIMULATE_HUMIDITY_MALFUNCTION){
        dbg("debug", "MODULES FUNCTION RESTORED TO NORMAL\n");
        smokeMalfunction = FALSE;
        gpsMalfunction = FALSE;
        humidityMalfunction = FALSE;
        temperatureMalfunction = FALSE;
      }
      else if(rpkt->msg_type == SMOKE){
        if(TOS_NODE_ID >=0 && TOS_NODE_ID < 100){
          //verifica se o timestamp e mais recente que o da ultima mensagem recebida
          int timestampMsg = rpkt->hour*10000 + rpkt->minutes*100 + rpkt->seconds;
          int dateMsg = rpkt->year*10000 + rpkt->month*100 + rpkt->day;
          //tempo (horas) recebido e maior que o da ultima mensagem recebida
          if(timestampMsg > lastTimeStamp[rpkt->nodeid]){
            lastTimeStamp[rpkt->nodeid] = timestampMsg;
            lastDate[rpkt->nodeid] = dateMsg;
            if(TOS_NODE_ID == 0)
            {
              dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [SMOKE] Sensor Node %d located at x: %d and y: %d detected smoke(%d).\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, rpkt->nodeid, rpkt->x, rpkt->y, rpkt->smoke);
              dbg("log", "<%2d:%02d:%02d %02d/%02d/%d> Sensor Node %d located at x: %d and y: %d detected smoke(%d).\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, rpkt->nodeid, rpkt->x, rpkt->y, rpkt->smoke);
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

                rpktR->smoke = rpkt->smoke;

                if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(radio_msg)) == SUCCESS) {
                  busy = TRUE;
                  dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d>[SMOKE] Message Sent from %d to %d (init in sensorNode %d).\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, TOS_NODE_ID, rpktR->dest, rpktR->nodeid);
                }
              }
            }
          }
          //tempo (horas) recebido e menor que o da ultima mensagem
          else
          {
            //vai ver a data, se a data recebida for maior guarda esses novos valores no log
            if((dateMsg > lastDate[rpkt->nodeid]) && (lastDate[rpkt->nodeid] != 0)){
              lastTimeStamp[rpkt->nodeid] = timestampMsg;
              lastDate[rpkt->nodeid] = dateMsg;
              //dbg("debug", "Sensor Node %d mesure of humidity: %d%% and temperature: %d at %2d:%02d:%02d %02d/%02d/%d\n", rpkt->nodeid, rpkt->humidity, rpkt->temperature, rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year);
              if(TOS_NODE_ID == 0)
              {
                dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [SMOKE] Sensor Node located at x: %d and y: %d detected smoke(%d).\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, rpkt->nodeid, rpkt->x, rpkt->y, rpkt->smoke);
                dbg("log", "<%2d:%02d:%02d %02d/%02d/%d> Sensor Node %d located at x: %d and y: %d detected smoke(%d).\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, rpkt->nodeid, rpkt->x, rpkt->y, rpkt->smoke);
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

                  rpktR->smoke = rpkt->smoke;

                  if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(radio_msg)) == SUCCESS) {
                    busy = TRUE;
                    dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [SMOKE] Message Sent from %d to %d (init in sensorNode %d).\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, TOS_NODE_ID, rpktR->dest, rpktR->nodeid);
                  }
                }
              }
            }
          }
        }
      }
      else if(rpkt->msg_type == REGISTER){

        //SERVER
        if( TOS_NODE_ID == 0){
          //verifica se o sensorNode já se encontra registado
          int timestampMsg = rpkt->hour*10000 + rpkt->minutes*100 + rpkt->seconds;
          int dateMsg = rpkt->year*10000 + rpkt->month*100 + rpkt->day;
          //tempo (horas) recebido e maior que o da ultima mensagem recebida
          if((timestampMsg > lastAssignTimeStamp[rpkt->nodeid]) || (dateMsg > lastAssignDate[rpkt->nodeid])) {
            lastAssignTimeStamp[rpkt->nodeid] = timestampMsg;
            lastAssignDate[rpkt->nodeid] = dateMsg;
            registeredNodes[rpkt->nodeid] = rpkt->routingNode;
            positionXSensorNodes[rpkt->nodeid] = rpkt->x;
            positionYSensorNodes[rpkt->nodeid] = rpkt->y;
            //dbg("debug", "routingNode: %d\n", rpkt->routingNode);
            dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [REGISTER] Sensor Node %d registered with positions x: %d and y: %d\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, rpkt->nodeid, rpkt->x, rpkt->y);
            dbg("log", "<%2d:%02d:%02d %02d/%02d/%d> Sensor Node %d registered with positions x: %d and y: %d.\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, rpkt->nodeid, rpkt->x, rpkt->y);
            //envia mensagem ao routing node a dizer que ficou com aquele sensor node
            if(!busy){
              radio_msg* rpktR = (radio_msg*)(call Packet.getPayload(&pkt, sizeof (radio_msg)));
              rpktR->msg_type = ASSIGN_SNODE;        
              rpktR->nodeid = rpkt->nodeid;
              rpktR->dest = rpkt->routingNode;

              time(&rawtime);
              info = gmtime(&rawtime);
              rpktR->seconds = info->tm_sec;
              rpktR->minutes = info->tm_min;
              rpktR->hour = info->tm_hour+BST;
              rpktR->day = info->tm_mday;
              rpktR->month = info->tm_mon;
              rpktR->year = info->tm_year+1900;

              if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(radio_msg)) == SUCCESS) {
                busy = TRUE;
                dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [REGISTER -> ASSIGN_SNODE] Message Sent from %d to %d (init in sensorNode %d).\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, TOS_NODE_ID, rpkt->routingNode, rpktR->nodeid);
              }
            }
            else {
              dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [REGISTER -> ASSIGN_NODE -> QUEUE] RN buffer is busy. Sending message to queue\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year);
              msg_q[msg_q_cnt].msg_type = ASSIGN_SNODE;        
              msg_q[msg_q_cnt].nodeid = rpkt->nodeid;
              msg_q[msg_q_cnt].dest = rpkt->routingNode;

              //REGISTER vars
              msg_q[msg_q_cnt].counter=0;
              msg_q[msg_q_cnt].randvalue=0;
              msg_q[msg_q_cnt].routingNode=0;

              // Timestamp
              time(&rawtime);
              info = gmtime(&rawtime);
              msg_q[msg_q_cnt].seconds = info->tm_sec;
              msg_q[msg_q_cnt].minutes = info->tm_min;
              msg_q[msg_q_cnt].hour = info->tm_hour+BST;
              msg_q[msg_q_cnt].day = info->tm_mday;
              msg_q[msg_q_cnt].month = info->tm_mon;
              msg_q[msg_q_cnt].year = info->tm_year+1900;

              // GPS coordinates
              msg_q[msg_q_cnt].x=0;
              msg_q[msg_q_cnt].y=0;

              // Humidity information
              msg_q[msg_q_cnt].humidity=0;

              // Temperature information
              msg_q[msg_q_cnt].temperature=0;

              // Smoke information
              msg_q[msg_q_cnt].smoke=0;

              msg_q_cnt++;
            }
          }
        }

        //ROUTING NODES
        else if( TOS_NODE_ID <= 99 && TOS_NODE_ID >= 1){
          //verificar se ja recebeu a mesma msg antes
          int timestampMsg = rpkt->hour*10000 + rpkt->minutes*100 + rpkt->seconds;
          int dateMsg = rpkt->year*10000 + rpkt->month*100 + rpkt->day;
          //tempo (horas) recebido e maior que o da ultima mensagem recebida
          if(timestampMsg > lastTimeStampRegister[rpkt->nodeid]){
            lastTimeStampRegister[rpkt->nodeid] = timestampMsg;
            lastDateRegister[rpkt->nodeid] = dateMsg;
            if(!busy){

              radio_msg* rpktR = (radio_msg*)(call Packet.getPayload(&pkt, sizeof (radio_msg)));
              //dbg("debug", "[REGISTER -> RN] RN: %d\n", TOS_NODE_ID);
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

              //dbg("debug", "COUNTER: %d\n", rpkt->counter);
              if(rpkt->counter == 0){
                //randValue 0 e 200
                uint8_t rv = rand()%201;

                rpktR->routingNode = TOS_NODE_ID;
                rpktR->randvalue = rv;
                rpktR->counter = rpkt->counter + 1;
              }
              else
              {
                rpktR->routingNode = rpkt->routingNode;
                rpktR->randvalue = rpkt->randvalue;
                rpktR->counter = rpkt->counter + 1;
              }

              if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(radio_msg)) == SUCCESS) {
                busy = TRUE;
                dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [REGISTER] Message Sent from %d to %d (init in sensorNode %d).\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, TOS_NODE_ID, rpktR->dest, rpktR->nodeid);
              }
            }
            else {
              dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [REGISTER -> QUEUE] RN buffer is busy. Sending message to queue\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year);
              msg_q[msg_q_cnt].msg_type = rpkt->msg_type;        
              msg_q[msg_q_cnt].nodeid = rpkt->nodeid;
              msg_q[msg_q_cnt].dest = rpkt->dest;
              
              msg_q[msg_q_cnt].seconds = rpkt->seconds;
              msg_q[msg_q_cnt].minutes = rpkt->minutes;
              msg_q[msg_q_cnt].hour = rpkt->hour;
              msg_q[msg_q_cnt].day = rpkt->day;
              msg_q[msg_q_cnt].month = rpkt->month;
              msg_q[msg_q_cnt].year = rpkt->year;

              msg_q[msg_q_cnt].x = rpkt->x;
              msg_q[msg_q_cnt].y = rpkt->y;


              // Humidity information
              msg_q[msg_q_cnt].humidity=0;

              // Temperature information
              msg_q[msg_q_cnt].temperature=0;

              // Smoke information
              msg_q[msg_q_cnt].smoke=0;

              //dbg("debug", "COUNTER: %d\n", rpkt->counter);
              if(rpkt->counter == 0){
                //randValue 0 e 200
                uint8_t rv = rand()%201;

                msg_q[msg_q_cnt].routingNode = TOS_NODE_ID;
                msg_q[msg_q_cnt].randvalue = rv;
                msg_q[msg_q_cnt].counter = rpkt->counter + 1;
                msg_q_cnt++;
              }
              else
              {
                msg_q[msg_q_cnt].routingNode = rpkt->routingNode;
                msg_q[msg_q_cnt].randvalue = rpkt->randvalue;
                msg_q[msg_q_cnt].counter = rpkt->counter + 1;
                msg_q_cnt++;
              }          
            }
          } else if((dateMsg > lastDate[rpkt->nodeid]) && (lastDate[rpkt->nodeid] != 0)){
              lastTimeStamp[rpkt->nodeid] = timestampMsg;
              lastDate[rpkt->nodeid] = dateMsg;

              if(!busy){

                radio_msg* rpktR = (radio_msg*)(call Packet.getPayload(&pkt, sizeof (radio_msg)));
                dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [REGISTER -RN] RN: %d\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, TOS_NODE_ID);
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

                //dbg("debug", "COUNTER: %d\n", rpkt->counter);
                if(rpkt->counter == 0){
                  //randValue 0 e 200
                  uint8_t rv = rand()%201;

                  rpktR->routingNode = TOS_NODE_ID;
                  rpktR->randvalue = rv;
                  rpktR->counter = rpkt->counter + 1;
                }
                else
                {
                  rpktR->routingNode = rpkt->routingNode;
                  rpktR->randvalue = rpkt->randvalue;
                  rpktR->counter = rpkt->counter + 1;
                }

                if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(radio_msg)) == SUCCESS) {
                  busy = TRUE;
                  dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [REGISTER] Message Sent from %d to %d (init in sensorNode %d).\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, TOS_NODE_ID, rpktR->dest, rpktR->nodeid);
                }
              }
              else {
                dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [REGISTER -> QUEUE] RN buffer is busy. Sending message to queue\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year);
                msg_q[msg_q_cnt].msg_type = rpkt->msg_type;        
                msg_q[msg_q_cnt].nodeid = rpkt->nodeid;
                msg_q[msg_q_cnt].dest = rpkt->dest;
                
                msg_q[msg_q_cnt].seconds = rpkt->seconds;
                msg_q[msg_q_cnt].minutes = rpkt->minutes;
                msg_q[msg_q_cnt].hour = rpkt->hour;
                msg_q[msg_q_cnt].day = rpkt->day;
                msg_q[msg_q_cnt].month = rpkt->month;
                msg_q[msg_q_cnt].year = rpkt->year;

                msg_q[msg_q_cnt].x = rpkt->x;
                msg_q[msg_q_cnt].y = rpkt->y;


                // Humidity information
                msg_q[msg_q_cnt].humidity=0;

                // Temperature information
                msg_q[msg_q_cnt].temperature=0;

                // Smoke information
                msg_q[msg_q_cnt].smoke=0;

                //dbg("debug", "COUNTER: %d\n", rpkt->counter);
                if(rpkt->counter == 0){
                  //randValue 0 e 200
                  uint8_t rv = rand()%201;

                  msg_q[msg_q_cnt].routingNode = TOS_NODE_ID;
                  msg_q[msg_q_cnt].randvalue = rv;
                  msg_q[msg_q_cnt].counter = rpkt->counter + 1;
                  msg_q_cnt++;
                }
                else
                {
                  msg_q[msg_q_cnt].routingNode = rpkt->routingNode;
                  msg_q[msg_q_cnt].randvalue = rpkt->randvalue;
                  msg_q[msg_q_cnt].counter = rpkt->counter + 1;
                  msg_q_cnt++;
                }          
              }
            }
        }
      } //closes
      else if(rpkt->msg_type == MEASURES){

        if(TOS_NODE_ID >=0 && TOS_NODE_ID < 100){
          //verifica se o timestamp e mais recente que o da ultima mensagem recebida
          int timestampMsg = rpkt->hour*10000 + rpkt->minutes*100 + rpkt->seconds;
          int dateMsg = rpkt->year*10000 + rpkt->month*100 + rpkt->day;
          //tempo (horas) recebido e maior que o da ultima mensagem recebida
          if(timestampMsg > lastTimeStamp[rpkt->nodeid]){
            lastTimeStamp[rpkt->nodeid] = timestampMsg;
            lastDate[rpkt->nodeid] = dateMsg;
            //dbg("debug", "Sensor Node %d mesure of humidity: %d%% and temperature: %d at %2d:%02d:%02d %02d/%02d/%d\n", rpkt->nodeid, rpkt->humidity, rpkt->temperature, rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year);
            if(TOS_NODE_ID == 0)
            {
              dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [MEASURE] Sensor Node %d located at x: %d and y: %d measured humidity: %d%% and temperature: %d.\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, rpkt->nodeid, rpkt->x, rpkt->y, rpkt->humidity, rpkt->temperature);
              dbg("log", "<%2d:%02d:%02d %02d/%02d/%d> Sensor Node %d located at x: %d and y: %d measured humidity: %d%% and temperature: %d.\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, rpkt->nodeid, rpkt->x, rpkt->y, rpkt->humidity, rpkt->temperature);
            } 
            else
            {

              int i;
              bool mine = FALSE;
              int id = rpkt->nodeid;
              dbg("debug", "++++++++ COUNTER: %d ++++++++\n", rpkt->counter);
              for(i=0; i<100; i++){
                if(mySensorNodes[i] == id){
                  mine = TRUE;
                  break;
                }
              }
              if(!busy && ((mine && rpkt->counter == 0) || (rpkt->counter > 0 && !mine))) {
                radio_msg* rpktR = (radio_msg*)(call Packet.getPayload(&pkt, sizeof (radio_msg)));

                rpktR->msg_type = rpkt->msg_type;        
                rpktR->nodeid = rpkt->nodeid;
                rpktR->dest = rpkt->dest;
                rpktR->x = rpkt->x;
                rpktR->y = rpkt->y;
                rpktR->counter = rpkt->counter + 1;
                
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
                  dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [MEASURE] Message Sent from %d to %d (init in sensorNode %d).\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, TOS_NODE_ID, rpktR->dest, rpktR->nodeid);
                }
              }
            }
          }
          //tempo (horas) recebido e menor que o da ultima mensagem
          else
          {
            //vai ver a data, se a data recebida for maior guarda esses novos valores no log
            if((dateMsg > lastDate[rpkt->nodeid]) && (lastDate[rpkt->nodeid] != 0)){
              lastTimeStamp[rpkt->nodeid] = timestampMsg;
              lastDate[rpkt->nodeid] = dateMsg;
              //dbg("debug", "Sensor Node %d mesure of humidity: %d%% and temperature: %d at %2d:%02d:%02d %02d/%02d/%d\n", rpkt->nodeid, rpkt->humidity, rpkt->temperature, rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year);
              if(TOS_NODE_ID == 0)
              {
                dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [MEASURE] Sensor Node %d located at x: %d and y: %d measured humidity: %d%% and temperature: %d.\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, rpkt->nodeid, rpkt->x, rpkt->y, rpkt->humidity, rpkt->temperature);
                dbg("log", "<%2d:%02d:%02d %02d/%02d/%d> Sensor Node %d located at x: %d and y: %d measured humidity: %d%% and temperature: %d.\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, rpkt->nodeid, rpkt->x, rpkt->y, rpkt->humidity, rpkt->temperature);
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
                    dbg("debug", "<%2d:%02d:%02d %02d/%02d/%d> [MEASURE] Message Sent from %d to %d (init in sensorNode %d).\n", rpkt->hour, rpkt->minutes, rpkt->seconds, rpkt->day, rpkt->month, rpkt->year, TOS_NODE_ID, rpktR->dest, rpktR->nodeid);
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
