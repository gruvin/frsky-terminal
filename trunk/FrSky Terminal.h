//
//  FrSky Controller.h
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
 
    This app does NOT comply with MVC model ideals (at all) because to separate the low level comms
    data processing into a sepoarate model would have meant implementing protocols and
    notifications, just to keep the tony amount amount of data separate from the view 
    controller. For a small app like this, that just didn't make an ounce of sense, 
    to me. Doing so would have also made execution less efficient, by doubling up
    on data variables and needing more code to process it.
                                                                             -- Gruvin.
 */


#import <Cocoa/Cocoa.h>

// We are going to be dropping down into pure C for serial comms, so we need some old fashioned includes ...
#include <stdio.h>   /* Standard input/output definitions */
#include <string.h>  /* String function definitions */
#include <unistd.h>  /* UNIX standard function definitions */
#include <fcntl.h>   /* File control definitions */
#include <errno.h>   /* Error number definitions */
#include <termios.h> /* POSIX terminal control definitions */
#include <stdlib.h>
#include <sys/ioctl.h>

#include <IOKit/serial/IOSerialKeys.h>
#include <libgen.h>


#define DEBUG 0

@interface FrSky_Terminal : NSObject <NSApplicationDelegate, NSComboBoxDelegate> {

    int fd; /* File descriptor for the port */
	char buffer[255];  /* Input buffer */
	int  nbytes;       /* Number of bytes read */
	char devicePath[1024];

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
	
	NSTimer *repeatingTimer;
	
	BOOL timerBusy;
	
}

- (BOOL) openPort;
- (void) closePort;
- (void) processByte: ( unsigned char) c;
- (void) processPacket:(unsigned char *)packetBuf;
- (void) sendPacket: (unsigned char *)packetBuf : (int)length;

- (void)timerFireMethod:(NSTimer*)theTimer;

- (IBAction)alarmSetCh1A:(id)sender;
- (IBAction)alarmSetCh1B:(id)sender;
- (IBAction)alarmSetCh2A:(id)sender;
- (IBAction)alarmSetCh2B:(id)sender;
- (IBAction)alarmRefresh:(id)sender;


@property (assign) IBOutlet NSWindow *window;
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

@end
