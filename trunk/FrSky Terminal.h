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
    This app was originally thrown together in a blur of trying to learn Xcode v3.2 and
    Objective-C for the first time, in 2010. It was later updated to use newer Xcode 4 conventions, 
    like automatic property synthesis and ARC instead of garbage collection,  etc. Later still 
    (2013) the learning curve extended to making the program fully comply with the MVC design 
    pattern -- enabled for the most part by protocols and delegates.
                                                                                    -- Gruvin.
 */


#import <Cocoa/Cocoa.h>
#import "Telemetry Parser.h"

// We are going to use pure C system calls for serial comms ...
#include <fcntl.h>      /* File control definitions */
#include <termios.h>    /* POSIX terminal control definitions (baud, flow, data format constants) */
#include <libgen.h>     /* for basename() */

#include <IOKit/serial/IOSerialKeys.h>


#define DEBUG 0

@interface FrSky_Terminal : NSObject <NSApplicationDelegate, NSComboBoxDelegate, TelemtryParserDelegate>

@property (assign) IBOutlet NSWindow *window;

// Declare our model -- an instance of the TelemtryParser class
@property (strong) TelemetryParser *telemetryParser;

// Main view object properties
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

// Hub Data view properties
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


// Class methods
- (void) clearUserDataText;

// Interface Builder action methods
- (IBAction) refreshButton:(id)sender;
- (IBAction) alarmSet:(id)sender;
- (IBAction) alarmRefresh:(id)sender;
- (IBAction) clearUserData:(id)sender;
- (IBAction) dataModeSelected:(id)sender;


@end
