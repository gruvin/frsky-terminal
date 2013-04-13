//
//  FrSky Terminal.h
//  FrSky Terminal
//
//  Created by Bryan on 28/11/10.
//  Copyright 2010 Bryan J. Rentoul.
//  
//  This file is part of the computer application software named FrSky Terminal.
//  
//  FrSky Terminal is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//  
//  FrSky Terminal is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//  
//  You should have received a copy of the GNU General Public License
//  along with FrSky Terminal in a file named COPYING.  
//	If not, see <http://www.gnu.org/licenses/>.
//


// APPLICATION STRUCTURE
/*
    This app was originally thrown together in a blur of trying to learn Xcode v3.2. It
    was later updated to use Xcode 4 conventions, namely 'propertyizing' all outlets, etc.
 
    This app does NOT comply with MVC model ideals (at all) because to separate the low 
    level comms data processing into a sepoarate model would have meant implementing 
    protocols and notifications, just to keep the tony amount amount of data separate 
    from the view controller. For a small app like this, that just didn't make an ounce 
    of sense, to me. Doing so would have also made execution less efficient, by doubling 
    up on data variables and needing more code to process it.
                                                                             -- Gruvin.
 */


#import <Cocoa/Cocoa.h>

// We are going to use pure C system calls for serial comms ...
#include <fcntl.h>      /* File control definitions */
#include <termios.h>    /* POSIX terminal control definitions (baud, flow, data format constants) */
#include <libgen.h>     /* for basename() */

#include <IOKit/serial/IOSerialKeys.h>


#define DEBUG 0

// Primitive C data structures
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

@interface FrSky_Terminal : NSObject <NSApplicationDelegate, NSComboBoxDelegate> {

    // Primitive C class variables
    int fd;             // File descriptor for the serial port
	char buffer[255];   // Input buffer
	int  nbytes;        // Number of bytes read
	char devicePath[1024];
    
    // Fr-Sky Hub data struct
    struct FrskyHubData frskyHubDataStruct;
    
    // Window form objects
    NSComboBox *_serialDeviceCombo;
	NSTextView *_userData;
	NSTextField *_myLabel;
	NSTextField *_textA1;
	NSTextField *_textA2;
	NSTextField *_textRSSI;
	NSLevelIndicatorCell *_signalLevel;
	NSLevelIndicatorCell *_bufferCount;
	NSLevelIndicatorCell *_dataStreamIndicator;
	NSPopUpButton *_displayMode;
	NSPopUpButton *_alarmCh1ALevel;
	NSPopUpButton *_alarmCh1BLevel;
	NSPopUpButton *_alarmCh2ALevel;
	NSPopUpButton *_alarmCh2BLevel;
	NSPopUpButton *_alarmCh1AGreater;
	NSPopUpButton *_alarmCh1BGreater;
	NSPopUpButton *_alarmCh2AGreater;
	NSPopUpButton *_alarmCh2BGreater;
	NSTextField *_alarmCh1AValue;
	NSTextField *_alarmCh1BValue;
	NSTextField *_alarmCh2AValue;
	NSTextField *_alarmCh2BValue;
	NSStepper *_alarmCh1AStepper;
	NSStepper *_alarmCh1BStepper;
	NSStepper *_alarmCh2AStepper;
	NSStepper *_alarmCh2BStepper;
    NSScrollView *_userDataTextView;
    NSBox *_telemetryBox;
    NSBox *_frskyHubBox;

    // Fr-Sky Views
    NSTextField *_frskyHubLattitude;
    NSTextField *_frskyHubLongitude;
    NSTextField *_frskyHubHeading;
    NSTextField *_frskyHubSpeed;
    NSTextField *_frskyHubAltitude;
    NSTextField *_frskyHubFuel;
    NSTextField *_frskyHubRPM;
    NSTextField *_frskyHubVolts;
    NSTextField *_frskyHubTemp1;
    NSTextField *_frskyHubTemp2;
    NSTextField *_frskyHubBaroAlt;
    NSTextField *_frskyHubData;
    
    // Other objects
	NSTimer *repeatingTimer;
	
    // Class variables
	BOOL timerBusy;

}


// Methods
- (BOOL) openSerialPort;
- (void) closeSerialPort;
- (void) processByte:  (unsigned char) c;
- (void) processPacket:(unsigned char *)packetBuf;
- (unsigned char) parseTelemHubIndex: (unsigned char) index;
- (void) parseTelemHubByte: (unsigned char) byte;
- (void) sendPacket: (unsigned char *)packetBuf : (int)length;
- (void) refreshSerialPortsList;
- (void) clearUserDataText;
- (void) updateFrSkyHubViews;


- (void)timerFiredEvent:(NSTimer*)theTimer;

// Action Methods
- (IBAction) refreshButton:(id)sender;
- (IBAction) alarmSetCh1A:(id)sender;
- (IBAction) alarmSetCh1B:(id)sender;
- (IBAction) alarmSetCh2A:(id)sender;
- (IBAction) alarmSetCh2B:(id)sender;
- (IBAction) alarmRefresh:(id)sender;
- (IBAction) clearUserData:(id)sender;
- (IBAction) dataModeSelected:(id)sender;

// Xcode supplied property
@property (assign) IBOutlet NSWindow *window;

// The "new thing" (Xcode 4) is to make all our outlet objects into properties and use dot notation (self.blah)
// Fortunately, Apple also added auto-synthesis magic to this scheme, so we don't have to do that tedium.

// Form object properties
@property (strong) IBOutlet NSComboBox *serialDeviceCombo;
@property (strong) IBOutlet NSTextView *userData;
@property (strong) IBOutlet NSTextField *myLabel;
@property (strong) IBOutlet NSTextField *textA1;
@property (strong) IBOutlet NSTextField *textA2;
@property (strong) IBOutlet NSTextField *textRSSI;
@property (strong) IBOutlet NSLevelIndicatorCell *signalLevel;
@property (strong) IBOutlet NSLevelIndicatorCell *bufferCount;
@property (strong) IBOutlet NSLevelIndicatorCell *dataStreamIndicator;
@property (strong) IBOutlet NSPopUpButton *displayMode;
@property (strong) IBOutlet NSPopUpButton *alarmCh1ALevel;
@property (strong) IBOutlet NSPopUpButton *alarmCh1BLevel;
@property (strong) IBOutlet NSPopUpButton *alarmCh2ALevel;
@property (strong) IBOutlet NSPopUpButton *alarmCh2BLevel;
@property (strong) IBOutlet NSPopUpButton *alarmCh1AGreater;
@property (strong) IBOutlet NSPopUpButton *alarmCh1BGreater;
@property (strong) IBOutlet NSPopUpButton *alarmCh2AGreater;
@property (strong) IBOutlet NSPopUpButton *alarmCh2BGreater;
@property (strong) IBOutlet NSTextField *alarmCh1AValue;
@property (strong) IBOutlet NSTextField *alarmCh1BValue;
@property (strong) IBOutlet NSTextField *alarmCh2AValue;
@property (strong) IBOutlet NSTextField *alarmCh2BValue;
@property (strong) IBOutlet NSStepper *alarmCh1AStepper;
@property (strong) IBOutlet NSStepper *alarmCh1BStepper;
@property (strong) IBOutlet NSStepper *alarmCh2AStepper;
@property (strong) IBOutlet NSStepper *alarmCh2BStepper;
@property (strong) IBOutlet NSBox *telemetryBox;
@property (strong) IBOutlet NSScrollView *userDataTextView;
@property (strong) IBOutlet NSBox *frskyHubBox;

@property (strong) IBOutlet NSTextField *frskyHubLattitude;
@property (strong) IBOutlet NSTextField *frskyHubLongitude;
@property (strong) IBOutlet NSTextField *frskyHubHeading;
@property (strong) IBOutlet NSTextField *frskyHubSpeed;
@property (strong) IBOutlet NSTextField *frskyHubAltitude;
@property (strong) IBOutlet NSTextField *frskyHubFuel;
@property (strong) IBOutlet NSTextField *frskyHubRPM;
@property (strong) IBOutlet NSTextField *frskyHubVolts;
@property (strong) IBOutlet NSTextField *frskyHubTemp1;
@property (strong) IBOutlet NSTextField *frskyHubTemp2;
@property (strong) IBOutlet NSTextField *frskyHubData;
@property (strong) IBOutlet NSTextField *frskyHubBaroAlt;

@end
