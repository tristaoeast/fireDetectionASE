#ifndef RADIO_H
#define RADIO_H

#define REGISTER 0
#define MEASURES 1
#define SMOKE 2
#define SIMULATE_FIRE 3
#define PUT_OUT_FIRE 4
#define ASSIGN_SNODE 5
#define SIMULATE_SMOKE_MALFUNCTION 6
#define SIMULATE_GPS_MALFUNCTION 7
#define SIMULATE_HUMIDITY_MALFUNCTION 8
#define SIMULATE_TEMPERATURE_MALFUNCTION 9
#define RESTORE_MALFUNCTION 10
#define RE_REGISTER 11
#define UN_ASSIGN_SNODE 12

 
enum {
  AM_RADIO_MSG = 6,
  T_MEASURE = 600000, //1 minute -> 6000000 = 60 seconds
  T_SMOKE_MEASURE = 150000, // 15 seconds
  T_ALIVE_MEASURE = 3000000, // 5 minutes
  T_REGISTER_CHECK = 100000, //   10 seconds
};
 
typedef nx_struct radio_msg {

  nx_uint8_t msg_type;
  nx_uint16_t nodeid;
  nx_uint16_t dest;

  //REGISTER vars
  nx_uint16_t counter;
  nx_uint8_t routingNode;

  // Timestamp
  nx_uint8_t seconds;
  nx_uint8_t minutes;
  nx_uint8_t hour;
  nx_uint8_t day;
  nx_uint8_t month;
  nx_uint8_t year;

  // GPS coordinates
  nx_int16_t x;
  nx_int16_t y;

  // Humidity information
  nx_int8_t humidity;

  // Temperature information
  nx_int8_t temperature;

  // Smoke information
  nx_int8_t smoke;


} radio_msg;

#endif
