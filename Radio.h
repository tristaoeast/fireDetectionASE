#ifndef RADIO_H
#define RADIO_H

#define REGISTER 0
#define MEASURES 1
#define SMOKE 2
#define SIMULATE_FIRE 3
#define PUT_OUT_FIRE 4

 
enum {
  AM_RADIO_MSG = 6,
  T_MEASURE = 10000, //10000 corresponds to 1 second
  T_SMOKE_MEASURE = 1000000,
};
 
typedef nx_struct radio_msg {

  nx_uint8_t msg_type;

  nx_uint16_t nodeid;
  nx_uint16_t counter;
  nx_uint16_t randvalue;

  nx_uint16_t dest;

  // Timestamp
  nx_uint8_t seconds;
  nx_uint8_t minutes;
  nx_uint8_t hour;
  nx_uint8_t day;
  nx_uint8_t month;
  nx_uint8_t year;

  // GPS coordinates
  nx_uint16_t x;
  nx_uint16_t y;

  // Humidity information
  nx_uint8_t humidity;

  // Temperature information
  nx_uint8_t temperature;

  // Smoke information
  nx_uint8_t smoke;


} radio_msg;

#endif
