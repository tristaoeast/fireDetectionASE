#ifndef C_TIME_H
#define C_TIME_H

#include <time.h>

typedef struct  c_time{
        int ct_sec;
        int ct_min;
        int ct_hour;
        int ct_mday;
        int ct_mon;
        int ct_year;
} c_time_t;

c_time_t getTime();

#endif