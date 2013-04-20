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

#define FRSKY_TELEM_BUFFER_SIZE 1024
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


#define DATA_STREAM_STOPPED 3
#define DATA_STREAM_PAUSED  2
#define DATA_STREAM_FLOWING 1

typedef enum {
    TS_IDLE = 0,  // waiting for 0x5e frame marker
    TS_DATA_ID,   // waiting for dataID
    TS_DATA_LOW,  // waiting for data low byte
    TS_DATA_HIGH, // waiting for data high byte
    TS_XOR = 0x80 // decode stuffed byte
} HUB_DATA_STATE;


struct FrskyAlarmData {
    uint8_t level;    // The alarm's 'urgency' level. 0=disabled, 1=yellow, 2=orange, 3=red
    uint8_t greater;  // 1 = 'if greater than'. 0 = 'if less than'
    uint8_t value;    // The threshold above or below which the alarm will sound
};

struct FrskyLinkData {
    unsigned char frskyA1Value;                         // Holds most recently parsed Fr-Sky Receiver A1 analogue input port value
    unsigned char frskyA2Value;                         // Holds most recently parsed Fr-Sky Receiver A2 analogue input port value
    unsigned char frskyRSSI1;
    unsigned char frskyRSSI2;
};

@protocol TelemtryParserDelegate <NSObject>
@optional
- (BOOL) telemetryParserShouldProcessFrskyHubData;
- (void) frskyLinkDataArrivedInCStruct:(struct FrskyLinkData) linkData;
- (void) frskyUserDataArrivedInString:(NSString *) userData;
- (void) frskyHubDataArrivedInCStruct:(struct FrskyHubData) hubData;
- (void) frskyAlarmDataArrivedInCStruct:(struct FrskyAlarmData) alarmData forAlarmIndex:(NSInteger)index;
- (void) telemtryDataStreamStatusChangedTo:(NSInteger) newValue;
- (void) telemetryParserBufferLevelNowAt:(NSInteger)byteCount;
@end


@interface TelemetryParser : NSObject <NSComboBoxDataSource>
{
    
    // Primitive C class variables
    int _serialPortFileDescriptor;                       // System file descriptor for serial port device access
	char _serialPortDevicePath[1024];                    // holds full path to /dev/tty.* serial device file
    
    unsigned char _telemetryDataBuffer[FRSKY_TELEM_BUFFER_SIZE];
    
    struct FrskyLinkData _frskyLinkData;
    struct FrskyAlarmData _frskyAlarmsStruct[4];
    struct FrskyHubData _frskyHubDataStruct;
    
    // No external access to these, so don't bother with prperties ...
    NSTimer *_dataPollingTimer;
	BOOL _dataPollingTimerEventInProgress;

}

@property (nonatomic) NSInteger telemetryDataBufferUsage; // The number of bytes grabbed in last serial port read() operation (for buffer use display)

@property (nonatomic) NSInteger telemtryDataStreamStatus;   // 3 = no data (in too long a time)
                                                            // 2 = pause in data data
                                                            // 1 = data flowing in steadily

// delegate instances should be weak, to avoid "reference cycles" with deallocated delegate objects
@property (nonatomic, weak) id <TelemtryParserDelegate> delegate;

- (void) refreshSerialDeviceList;
- (BOOL) openSerialPort: (NSString *) deviceName;  // Device file's basename
- (void) closeSerialPort;

- (void) sendAlarmSetPacketWithHeaderByte:(unsigned char)headerByte usingAlarmDataCStruct:(struct FrskyAlarmData) alarmData;
- (void) requestAlarmSettings;


// NSComboBoxDataSource methods
- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index;
- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox;

@end

