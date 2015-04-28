#include <stdlib.h>

module humidityDetectorC {
	uses interface Boot;
	provides interface humidityDetector;
}

implementation {
	
	nx_uint8_t humidity;

	event void Boot.booted() {
		
    }
	
	command nx_uint8_t humidityDetector.getHumidity() {
		//range 40 a 90, ver melhor
		humidity = (rand() % 51) + 40;
		return humidity;
 	}
}