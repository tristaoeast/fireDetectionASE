 #include <Timer.h>
 #include "Radio.h"
 #include <time.h>
 
 module RadioC {
  uses {
    interface Boot;
    interface Leds;
    interface Receive;
    interface Timer<TMilli> as SensorTimer;
    interface Packet;
    interface AMPacket;
    interface AMSend;
    interface SplitControl as AMControl;
    interface gps;
  }
 }
 implementation {
  bool busy = FALSE;
  message_t pkt;
  uint16_t counter = 0;
  position_t p;
  time_t rawtime;
  struct tm *info;
  int BST = 1;
 
  event void Boot.booted() {
    call AMControl.start();
    dbg("debug", "Node booted.\n");
    
  }

  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      // TODO: Register with server
      call SensorTimer.startPeriodic(T_MEASURE);
    }
    else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
  }
 
  event void SensorTimer.fired() {
    counter++;
    
     
    if(TOS_NODE_ID == 0){
      if (!busy) {
    		RadioMsg* btrpkt = (RadioMsg*)(call Packet.getPayload(&pkt, sizeof (RadioMsg)));
    		btrpkt->nodeid = TOS_NODE_ID;
    		btrpkt->counter = counter;
    		btrpkt->randvalue = rand() % 10;
		if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(RadioMsg)) == SUCCESS) {
			busy = TRUE;
			dbg("debug", "Message Send.\n");

      time(&rawtime);
      /* Get GMT time */
      info = gmtime(&rawtime);
      
      dbg("debug", "London : %2d:%02d:%02d %02d/%02d/%d\n", (info->tm_hour+BST), info->tm_min, info->tm_sec, info->tm_mday, info->tm_mon+1, 1900 + info->tm_year);
		}
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
  if (len == sizeof(RadioMsg)) {
    RadioMsg* btrpkt = (RadioMsg*)payload;
    dbg("debug", "Message Received from %d with random value %d and counter %d.\n", btrpkt->nodeid, btrpkt->randvalue, btrpkt->counter);
    if( TOS_NODE_ID == 1){
		if(!busy){
			RadioMsg* btrpktR = (RadioMsg*)(call Packet.getPayload(&pkt, sizeof (RadioMsg)));
		    btrpktR->nodeid = btrpkt->nodeid;
		    btrpktR->counter = btrpkt->counter;
		    btrpktR->randvalue = btrpkt->randvalue;
			if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(RadioMsg)) == SUCCESS) {
				busy = TRUE;
				dbg("debug", "Message Sent from %d with counter %d.\n", TOS_NODE_ID, btrpktR->counter);
			}
		}

    }
  }
  return msg;
}

 }
