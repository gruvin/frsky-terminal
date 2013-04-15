//
//  Telemetry Parser.h
//  FrSky Terminal
//
//  Created by Bryan on 15/04/13.
//  Copyright (c) 2013 Gruvin. All rights reserved.
//

#import <Foundation/Foundation.h>

// We are going to use pure C system calls for serial comms ...
#include <fcntl.h>      /* File control definitions */
#include <termios.h>    /* POSIX terminal control definitions (baud, flow, data format constants) */
#include <libgen.h>     /* for basename() */
#include <IOKit/serial/IOSerialKeys.h> /* For retrieving list of available serial ports */


struct FrskyHubData {
    int16_t  gpsAltitude_bp;   // before punct
    int16_t  temperature1;     // -20 .. 250 deg. celcius
    uint16_t rpm;              // 0..60,000 revs. per minute
    uint16_t fuelLevel;        // 0, 25, 50, 75, 100 percent
    int16_t  temperature2;     // -20 .. 250 deg. celcius
    uint16_t volts;            // 1/500V increments (0..4.2V)
    int16_t  gpsAltitude_ap;   // after punct
    int16_t  baroAltitude;     // 0..9,999 meters
    uint16_t gpsSpeed_bp;      // before punct
    uint16_t gpsLongitude_bp;  // before punct
    uint16_t gpsLatitude_bp;   // before punct
    uint16_t gpsCourse_bp;     // before punct (0..359.99 deg. -- seemingly 2-decimal precision)
    uint8_t  day;
    uint8_t  month;
    uint16_t year;
    uint8_t  hour;
    uint8_t  min;
    uint16_t sec;
    uint16_t gpsSpeed_ap;
    uint16_t gpsLongitude_ap;
    uint16_t gpsLatitude_ap;
    uint16_t gpsCourse_ap;
    uint16_t gpsLongitudeEW;   // East/West
    uint16_t gpsLatitudeNS;    // North/South
    int16_t  accelX;           // 1/256th gram (-8g ~ +8g)
    int16_t  accelY;           // 1/256th gram (-8g ~ +8g)
    int16_t  accelZ;           // 1/256th gram (-8g ~ +8g)
};

#define FRSKY_TELEM_BUFFER_SIZE 255
#define FRSKY_USER_DATA_BUFFER_SIZE 255

#define FRSKY_RX_PACKET_SIZE 19
#define FRSKY_TX_PACKET_SIZE 12

#define TELEM_START_STOP    0x7e
#define TELEM_BYTE_STUFF    0x7d
#define TELEM_STUFF_MASK    0x20

typedef enum {
    IDLE,
    START,
    IN_FRAME,
    XOR
} FRSKY_DATA_STATE;

#define TELEM_PKT_TYPE_LINK     0xfe
#define TELEM_PKT_TYPE_USER     0xfd
#define TELEM_PKT_TYPE_A1A      0xfc
#define TELEM_PKT_TYPE_A1B      0xfb
#define TELEM_PKT_TYPE_A2A      0xfa
#define TELEM_PKT_TYPE_A2B      0xf9
#define TELEM_PKT_TYPE_ALARMS   0xf8
#define TELEM_PKT_TYPE_RSSI1    0xf7 /* what's this for? This data is part of LINK packet. */
#define TELEM_PKT_TYPE_RSSI2    0xf6 /* what's this for? This data is part of LINK packet. */

typedef enum {
    TS_IDLE = 0,  // waiting for 0x5e frame marker
    TS_DATA_ID,   // waiting for dataID
    TS_DATA_LOW,  // waiting for data low byte
    TS_DATA_HIGH, // waiting for data high byte
    TS_XOR = 0x80 // decode stuffed byte
} HUB_DATA_STATE;


struct FrskyAlarm {
    uint8_t level;    // The alarm's 'urgency' level. 0=disabled, 1=yellow, 2=orange, 3=red
    uint8_t greater;  // 1 = 'if greater than'. 0 = 'if less than'
    uint8_t value;    // The threshold above or below which the alarm will sound
};

@interface Telemetry_Parser : NSObject
{
    
    // Primitive C class variables
    int _serialPortFileDescriptor;                       // System file descriptor for serial port device access
	char _serialPortDevicePath[1024];                    // holds full path to /dev/tty.* serial device file
    
    unsigned char _telemetryDataBuffer[FRSKY_TELEM_BUFFER_SIZE];
    
    unsigned char _frskyA1Value;                         // Holds most recently parsed Fr-Sky Receiver A1 analogue input port value
    unsigned char _frskyA2Value;                         // Holds most recently parsed Fr-Sky Receiver A2 analogue input port value
    unsigned char _frskyRSSI1;
    unsigned char _frskyRSSI2;
    struct FrskyAlarm _frskyAlarmsStruct[4];
    struct FrskyHubData _frskyHubDataStruct;
    
    NSTimer *dataPollingTimer;
	BOOL dataPollingTimerEventInProgress;

    NSNumber *_telemetryDataBufferUse;                  // The number of bytes grabbed in last serial port read() operation (for buffer use display)
    NSNumber *_telemtryDataStreamStatus;                // 3 = no data (in too long a time), 2 = pause in data data, 1 = data flowing in steadily

}

@property (strong) NSNumber * telemetryDataBufferUse;
@property (strong, readonly) NSNumber *telemtryDataStreamStatus;


- (void) dataPollingEvent: (NSTimer *) theTimer;
- (BOOL) openSerialPort:  (NSString *) deviceName;       // Device name should not include /dev/ prefix. Just the device basename.
- (void) closeSerialPort;

- (void) parseTelemetryByte: (unsigned char) thisByte;
- (void) parseFrskyPacket: (unsigned char *) packetBuffer withByteCount: (int) byteCount;
- (void) parseTelemHubByte: (unsigned char) thisByte;

@end