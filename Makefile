COMPONENT=RadioAppC
BUILD_EXTRA_DEPS = RadioMsg.py RadioMsg.class
CLEAN_EXTRA = RadioMsg.py RadioMsg.class RadioMsg.java

RadioMsg.py: Radio.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=RadioMsg Radio.h radio_msg -o $@

RadioMsg.class: RadioMsg.java
	javac RadioMsg.java

RadioMsg.java: Radio.h
	mig java -target=$(PLATFORM) $(CFLAGS) -java-classname=RadioMsg Radio.h radio_msg -o $@


include $(MAKERULES)

PFLAGS += c_time.c
