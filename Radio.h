 #ifndef RADIO_H
 #define RADIO_H
 
 enum {
   AM_RADIO = 6,
   T_MEASURE = 10000, //10000 corresponds to 1 second
 };
 
typedef nx_struct RadioMsg {
  nx_uint16_t nodeid;
  nx_uint16_t counter;
  nx_uint16_t randvalue;

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


} RadioMsg;

#endif
