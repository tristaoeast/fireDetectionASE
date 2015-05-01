#include "c_time.h"

c_time_t getTime(){
	
	time_t rawtime;
  	struct tm *info;

	c_time_t t;
	time(&rawtime);
    info = gmtime(&rawtime);
    t->ct_sec = info->tm_sec;
    t->ct_min = info->tm_min;
    t->ct_hour = info->tm_hour+1;
    t->ct_mday = info->tm_mday;
    t->ct_mon = info->tm_mon;
    t->ct_year = info->tm_year+1900;

    /*t.ct_sec = info->tm_sec;
    t.ct_min = info->tm_min;
    t.ct_hour = info->tm_hour+1;
    t.ct_mday = info->tm_mday;
    t.ct_mon = info->tm_mon;
    t.ct_year = info->tm_year+1900;*/

    return t;
}