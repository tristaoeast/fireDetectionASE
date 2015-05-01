#include <stdlib.h>

module smokeDetectorC {
	uses interface Boot;
	provides interface smokeDetector;
}

implementation {
	
	//nx_uint8_t smoke;
	nx_uint8_t rv;

	event void Boot.booted() {
		
    }
	
	command bool smokeDetector.getSmoke() {
		rv = (rand() % 100);
		if(rv == 1)
			return TRUE;
		else
			return FALSE;
	}
}