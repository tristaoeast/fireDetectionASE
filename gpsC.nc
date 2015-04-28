#include "gps.h"
#include <stdlib.h>
#include <time.h>

module gpsC {
	uses interface Boot;
	provides interface gps;
}

implementation {
	
	position_t pos;
	
	event void Boot.booted() {
		pos.x = (rand() % 1000) + 1;
		pos.y = (rand() % 1000) + 1;
    }
	
	command	position_t gps.getPosition() {
		return pos;
	}
}
