#include <stdlib.h>

module temperatureDetectorC {
	uses interface Boot;
	provides interface temperatureDetector;
}

implementation {
	
	nx_uint8_t temp;

	event void Boot.booted() {
		
    }
	
	command nx_uint8_t temperatureDetector.getTemperature() {
		//range 20-40
		temp = (rand() % 21) + 20;
		return temp;
 	}
}