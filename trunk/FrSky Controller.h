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

#import <Cocoa/Cocoa.h>

@interface FrSky_Controller : NSObject {
	IBOutlet NSTextField *deviceName;
	IBOutlet NSTextView *userData;
	IBOutlet NSTextField *myLabel;
	IBOutlet NSTextField *textA1;
	IBOutlet NSTextField *textA2;
	IBOutlet NSTextField *textRSSI;
	IBOutlet NSLevelIndicatorCell *signalLevel;
	IBOutlet NSLevelIndicatorCell *bufferCount;
	IBOutlet NSLevelIndicatorCell *dataStreamIndicator;
	IBOutlet NSPopUpButton *displayMode;
	
	IBOutlet NSPopUpButton *alarmCh1ALevel;
	IBOutlet NSPopUpButton *alarmCh1BLevel;
	IBOutlet NSPopUpButton *alarmCh2ALevel;
	IBOutlet NSPopUpButton *alarmCh2BLevel;
	IBOutlet NSPopUpButton *alarmCh1AGreater;
	IBOutlet NSPopUpButton *alarmCh1BGreater;
	IBOutlet NSPopUpButton *alarmCh2AGreater;
	IBOutlet NSPopUpButton *alarmCh2BGreater;
	IBOutlet NSTextField *alarmCh1AValue;
	IBOutlet NSTextField *alarmCh1BValue;
	IBOutlet NSTextField *alarmCh2AValue;
	IBOutlet NSTextField *alarmCh2BValue;
	IBOutlet NSStepper *alarmCh1AStepper;
	IBOutlet NSStepper *alarmCh1BStepper;
	IBOutlet NSStepper *alarmCh2AStepper;
	IBOutlet NSStepper *alarmCh2BStepper;
	
	NSTimer *repeatingTimer;
	
	int fd; /* File descriptor for the port */
	char buffer[255];  /* Input buffer */
	int  nbytes;       /* Number of bytes read */
	char devicePath[255];
	BOOL timerBusy;
	
}

- (void)timerFireMethod:(NSTimer*)theTimer;

- (IBAction)setSerialDevice:(id)sender;

- (IBAction)alarmSetCh1A:(id)sender;
- (IBAction)alarmSetCh1B:(id)sender;
- (IBAction)alarmSetCh2A:(id)sender;
- (IBAction)alarmSetCh2B:(id)sender;
- (IBAction)alarmRefresh:(id)sender;

// FrSky_Controller *frskyController;

- (BOOL) openPort;
- (void) closePort;
- (void) processByte:(unsigned char) c;
- (void) processPacket:(unsigned char *)packetBuf;
- (void) sendPacket:(unsigned char *)packetBuf:(int)length;

@end
