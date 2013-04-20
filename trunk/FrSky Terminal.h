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

// Declare our model -- an instance of the TelemtryParser class.
// Lazy instantiation occurs in the getter for this property.
@property (strong, nonatomic) TelemetryParser *telemetryParser;

// Main view object properties
@property (weak, nonatomic) IBOutlet NSComboBox *serialDeviceCombo;
@property (unsafe_unretained) IBOutlet NSTextView *userData; // TextViews cannot be 'weak, nonatomic'. IB uses unsafe_unretained, instead.
@property (weak, nonatomic) IBOutlet NSTextField *myLabel;
@property (weak, nonatomic) IBOutlet NSTextField *textA1;
@property (weak, nonatomic) IBOutlet NSTextField *textA2;
@property (weak, nonatomic) IBOutlet NSTextField *textRSSI;
@property (weak, nonatomic) IBOutlet NSLevelIndicatorCell *signalLevel;
@property (weak, nonatomic) IBOutlet NSLevelIndicatorCell *bufferCount;
@property (weak, nonatomic) IBOutlet NSLevelIndicatorCell *dataStreamIndicator;
@property (weak, nonatomic) IBOutlet NSPopUpButton *displayMode;
@property (weak, nonatomic) IBOutlet NSPopUpButton *alarmCh1ALevel;
@property (weak, nonatomic) IBOutlet NSPopUpButton *alarmCh1BLevel;
@property (weak, nonatomic) IBOutlet NSPopUpButton *alarmCh2ALevel;
@property (weak, nonatomic) IBOutlet NSPopUpButton *alarmCh2BLevel;
@property (weak, nonatomic) IBOutlet NSPopUpButton *alarmCh1AGreater;
@property (weak, nonatomic) IBOutlet NSPopUpButton *alarmCh1BGreater;
@property (weak, nonatomic) IBOutlet NSPopUpButton *alarmCh2AGreater;
@property (weak, nonatomic) IBOutlet NSPopUpButton *alarmCh2BGreater;
@property (weak, nonatomic) IBOutlet NSTextField *alarmCh1AValue;
@property (weak, nonatomic) IBOutlet NSTextField *alarmCh1BValue;
@property (weak, nonatomic) IBOutlet NSTextField *alarmCh2AValue;
@property (weak, nonatomic) IBOutlet NSTextField *alarmCh2BValue;
@property (weak, nonatomic) IBOutlet NSStepper *alarmCh1AStepper;
@property (weak, nonatomic) IBOutlet NSStepper *alarmCh1BStepper;
@property (weak, nonatomic) IBOutlet NSStepper *alarmCh2AStepper;
@property (weak, nonatomic) IBOutlet NSStepper *alarmCh2BStepper;
@property (weak, nonatomic) IBOutlet NSBox *telemetryBox;
@property (weak, nonatomic) IBOutlet NSScrollView *userDataTextView;
@property (weak, nonatomic) IBOutlet NSBox *frskyHubBox;

// Hub Data view properties
@property (weak, nonatomic) IBOutlet NSTextField *frskyHubLattitude;
@property (weak, nonatomic) IBOutlet NSTextField *frskyHubLongitude;
@property (weak, nonatomic) IBOutlet NSTextField *frskyHubHeading;
@property (weak, nonatomic) IBOutlet NSTextField *frskyHubSpeed;
@property (weak, nonatomic) IBOutlet NSTextField *frskyHubAltitude;
@property (weak, nonatomic) IBOutlet NSTextField *frskyHubFuel;
@property (weak, nonatomic) IBOutlet NSTextField *frskyHubRPM;
@property (weak, nonatomic) IBOutlet NSTextField *frskyHubVolts;
@property (weak, nonatomic) IBOutlet NSTextField *frskyHubTemp1;
@property (weak, nonatomic) IBOutlet NSTextField *frskyHubTemp2;
@property (weak, nonatomic) IBOutlet NSTextField *frskyHubData;
@property (weak, nonatomic) IBOutlet NSTextField *frskyHubBaroAlt;


// Class methods
- (void) clearUserDataText;

// Interface Builder action methods
- (IBAction) refreshButton:(id)sender;
- (IBAction) alarmSet:(id)sender;
- (IBAction) alarmRefresh:(id)sender;
- (IBAction) clearUserData:(id)sender;
- (IBAction) dataModeSelected:(id)sender;


@end
