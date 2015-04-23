 #include <Timer.h>
 #include "BlinkToRadio.h"
 
 module BlinkToRadioC {
   uses interface Boot;
   uses interface Leds;
   uses interface Receive;
   uses interface Timer<TMilli> as Timer0;
   uses interface Packet;
   uses interface AMPacket;
   uses interface AMSend;
   uses interface SplitControl as AMControl;
 }
 implementation {
   bool busy = FALSE;
   message_t pkt;
   uint16_t counter = 0;
 
  event void Boot.booted() {
    call AMControl.start();
    dbg("BlinkToRadio", "Application booted.\n");
  }

  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      call Timer0.startPeriodic(TIMER_PERIOD_MILLI);
    }
    else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
  }
 
   event void Timer0.fired() {
     counter++;
     /*call Leds.set(counter);*/
     
   if(TOS_NODE_ID == 0){
    if (!busy) {
		BlinkToRadioMsg* btrpkt = (BlinkToRadioMsg*)(call Packet.getPayload(&pkt, sizeof (BlinkToRadioMsg)));
		btrpkt->nodeid = TOS_NODE_ID;
		btrpkt->counter = counter;
		btrpkt->randvalue = rand() % 10;
		if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(BlinkToRadioMsg)) == SUCCESS) {
			busy = TRUE;
			dbg("BlinkToRadio", "Message Send.\n");
		}
	}
   }
   }

  event void AMSend.sendDone(message_t* msg, error_t error) {
    if (&pkt == msg) {
      busy = FALSE;
      dbg("BlinkToRadio", "Busy FALSE.\n");
    }
  }

event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
  if (len == sizeof(BlinkToRadioMsg)) {
    BlinkToRadioMsg* btrpkt = (BlinkToRadioMsg*)payload;
    dbg("BlinkToRadio", "Message Received from %d with random value %d and counter %d.\n", btrpkt->nodeid, btrpkt->randvalue, btrpkt->counter);
    if( TOS_NODE_ID == 1){
		if(!busy){
			BlinkToRadioMsg* btrpktR = (BlinkToRadioMsg*)(call Packet.getPayload(&pkt, sizeof (BlinkToRadioMsg)));
		    btrpktR->nodeid = btrpkt->nodeid;
		    btrpktR->counter = btrpkt->counter;
		    btrpktR->randvalue = btrpkt->randvalue;
			if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(BlinkToRadioMsg)) == SUCCESS) {
				busy = TRUE;
				dbg("BlinkToRadio", "Message Sent from %d with counter %d.\n", TOS_NODE_ID, btrpktR->counter);
			}
		}

    }
  }
  return msg;
}

 }
