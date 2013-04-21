//
//  FrSky Terminal.m
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

#import "FrSky Terminal.h"


// Private properties/methods
@interface FrSky_Terminal()
@property (assign) IBOutlet NSWindow *window;

@property (weak, nonatomic) IBOutlet NSComboBox *serialDeviceCombo;

@property (weak, nonatomic) IBOutlet NSLevelIndicatorCell *signalLevel;
@property (weak, nonatomic) IBOutlet NSTextField *textA1;
@property (weak, nonatomic) IBOutlet NSTextField *textA2;
@property (weak, nonatomic) IBOutlet NSTextField *textRSSI;
@property (weak, nonatomic) IBOutlet NSLevelIndicatorCell *dataStreamIndicator;
@property (weak, nonatomic) IBOutlet NSLevelIndicatorCell *bufferCount;
@property (weak, nonatomic) IBOutlet NSPopUpButton *displayMode;

@property (weak, nonatomic) IBOutlet NSBox *telemetryBox;

@property (strong, nonatomic) IBOutlet NSScrollView *userDataTextView;
@property (unsafe_unretained) IBOutlet NSTextView *userData; // TextViews cannot be 'weak, nonatomic'. IB uses unsafe_unretained, instead.

@property (strong, nonatomic) IBOutlet NSBox *frskyHubBox;

// Alarm settings outlets
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
@property (weak, nonatomic) IBOutlet NSBox *alarmSettingsBox;

// Hub Data view outlets
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

// MODEL -- an instance of the TelemetryParser class.
// Lazy instantiation occurs in the getter for this property.
@property (strong, nonatomic) TelemetryParser *telemetryParser;

@end

@implementation FrSky_Terminal

// Custom getter to effect automatic lazy instantiation
- (TelemetryParser *)telemetryParser
{
    if (!_telemetryParser) _telemetryParser = [[TelemetryParser alloc] init];
    return _telemetryParser;
}

/////////////////////////
//  S T A R T  -  U P  //
/////////////////////////
- (void) applicationDidFinishLaunching:(NSNotification*)aNotification
{

    [self.telemetryParser setDelegate:self]; // make us the delegate for telemetryParser's FrskyParserDelegate protocol methods
    
    [self clearUserDataText];                // also sets font, etc
    
    [self.serialDeviceCombo setDataSource:self.telemetryParser];
	[self.serialDeviceCombo setStringValue:@"Select serial port ..."]; // and add a hint for the user

	// [self alarmRefresh:self]; // TODO: This would make much more sense are part of openSerialPort (model-side)
}

// Make the app terminate if its main window is closed.
- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}

- (void) applicationWillTerminate:(NSNotification *)aNotification
{
	[self.telemetryParser closeSerialPort];
}

- (IBAction) refreshButton:(id)sender {
    [self.telemetryParser refreshSerialDeviceList];
    [self.serialDeviceCombo noteNumberOfItemsChanged]; // reloadData is not sufficient
}

- (void) clearUserDataText
{
    [self.userData setEditable:YES];
    [self.userData setString:@""];
    [self.userData setFont:[NSFont fontWithName:@"Monaco" size:12.0]];
    [self.userData setEditable:NO];
}


/////////////////////////
/// ACTION METHODS

- (IBAction) clearUserData:(id)sender
{
    [self clearUserDataText];
}

// Change views (if needed) when a different data display mode is selected
- (IBAction) dataModeSelected:(id)sender
{
    if ([self.displayMode indexOfSelectedItem] == 3) // hub view
    {
        [self.frskyHubBox setFrame:[self.userDataTextView frame]];
        [self.telemetryBox replaceSubview:self.userDataTextView with:self.frskyHubBox];
    }
    else
    {
        [self.telemetryBox replaceSubview:self.frskyHubBox with:self.userDataTextView];
        
        [self clearUserDataText];
    }
}

- (IBAction)stepperValueHasChanged:(NSStepper *)sender {
    
    NSUInteger tagOfRelatedTextField = ((([sender tag]-1) / 4) * 4) + 3;
    
    [(NSTextField *)[[self.alarmSettingsBox contentView] viewWithTag:tagOfRelatedTextField]
        setIntValue:[sender intValue]];
    
    [self alarmSet:sender]; // to have this change sent to the Fr-Sky Tx module
    
}

- (IBAction) alarmSet:(id)sender
{
	
    unsigned char headerByte = 0;
    struct FrskyAlarmData alarmData;
    
    /* tags are set on alarm setting UI "Alarm Settings" views, disabled/enaabled, less/greater, value, stepper
       as follows ...
              Ch1 Alarm A tags=  9  10  11  12
              Ch1 Alarm B tags= 13  14  15  16
              Ch2 Alarm A tags=  1   2   3   4
              Ch2 Alarm B tags=  5   6   7   8                              */
    // 'sender' is any one of those same views, including the steppers.

    NSView *alarmViews = [self.alarmSettingsBox contentView];

    NSUInteger tagOfFirstViewOnThisRow = ((([sender tag]-1) / 4) * 4) + 1;
    
    NSUInteger rowNumber = (([sender tag]-1) / 4);
    headerByte = (unsigned char)(0xf9 + rowNumber);

    // Set the C Struct values
    alarmData.level   = (unsigned char)[(NSPopUpButton *)[alarmViews
                               viewWithTag:tagOfFirstViewOnThisRow + 0] indexOfSelectedItem];

    alarmData.greater = (unsigned char)[(NSPopUpButton *)[alarmViews
                               viewWithTag:tagOfFirstViewOnThisRow + 1] indexOfSelectedItem];

    alarmData.value   = (unsigned char)[(NSTextField *)[alarmViews
                               viewWithTag:tagOfFirstViewOnThisRow + 2] intValue];

    // Update this row's stepper value to the same as the text field's intValue
    NSStepper *thisRowsStepper = [alarmViews viewWithTag:tagOfFirstViewOnThisRow+3];
    [thisRowsStepper setIntValue:(int)alarmData.value];
    
    if (DEBUG) NSLog(@"AlarmData=H:%02x %d, %d, %d", headerByte, alarmData.level, alarmData.greater, alarmData.value);
    
    // Send new settings to the Fr-Sky Tx moudle
    [self.telemetryParser sendAlarmSetPacketWithHeaderByte:headerByte usingAlarmDataCStruct:alarmData];

}


- (IBAction) alarmRefresh:(id)sender
{
    [self.telemetryParser requestAlarmSettings];
}

///
/////////////////////////

/////////////////////////////////////
/// DELEGATE METHODS

- (BOOL) telemetryParserShouldProcessFrskyHubData
{
    return [self.displayMode indexOfSelectedItem] == 3; // hub view
}

- (void) frskyLinkDataArrivedInCStruct:(struct FrskyLinkData) linkData
{
    static int lastRSSI;
    
    [self.textA1 setIntValue: linkData.frskyA1Value];
    [self.textA2 setIntValue: linkData.frskyA2Value];
    [self.textRSSI setIntValue:lastRSSI = (lastRSSI == 0) ? linkData.frskyRSSI1 :
     (lastRSSI = (linkData.frskyRSSI1 + ((unsigned int)lastRSSI * 15)) >> 4)]; // averaging filter to prevent RSSI figure from jumping about too much on screen
    [self.signalLevel setIntValue:((lastRSSI/2) < 16) ? 16 : lastRSSI / 2];
}

- (void) frskyUserDataArrivedInString:(NSString *) userData
{
    [self.userData setEditable:YES];
    switch ([self.displayMode indexOfSelectedItem])
    {
        case 0:
            [self.userData insertText:userData];
            break;
            
        case 1: // HEX
            for (int i=0; i < [userData length]; i++)
                [self.userData insertText:[NSString stringWithFormat:@"%02x ", [userData characterAtIndex: i]]];
            break;
            
        case 2: // BCD
            for (int i=0; i < [userData length]; i++) {
                unsigned char theByte = [userData characterAtIndex: i];
                [self.userData insertText:[NSString stringWithFormat:@"%1u", (theByte&0x0f)]];
                [self.userData insertText:[NSString stringWithFormat:@":%1u ", ((theByte&0xf0)>>4)]];
            }
            break;
    }
    
    [self.userData setEditable:NO];
}

- (void) frskyHubDataArrivedInCStruct:(struct FrskyHubData) hubData
{

     char gpsLatitudeDirection = (hubData.gpsLatitudeNS == ' ') ? '-' : hubData.gpsLatitudeNS;
     char gpsLongitudeDirection = (hubData.gpsLongitudeEW == ' ') ? '-' : hubData.gpsLongitudeEW;
    
     [self.frskyHubLattitude setStringValue:[NSString stringWithFormat:@"%3dº%02d'%02d.%03d %c",
         hubData.gpsLatitude_bp/100,
         hubData.gpsLatitude_bp%100,
         hubData.gpsLatitude_ap * 6 / 1000,
         hubData.gpsLatitude_ap * 6 % 1000,
         gpsLatitudeDirection
     ]];
     [self.frskyHubLongitude setStringValue:[NSString stringWithFormat:@"%3dº%02d'%02d.%03d %c",
         hubData.gpsLongitude_bp/100,
         hubData.gpsLongitude_bp%100,
         hubData.gpsLongitude_ap * 6 / 1000,
         hubData.gpsLongitude_ap * 6 % 1000,
         gpsLongitudeDirection
     ]];
     [self.frskyHubHeading setStringValue:[NSString stringWithFormat:@"  %03dº", hubData.gpsCourse_bp]];
     [self.frskyHubSpeed setStringValue:[NSString stringWithFormat:@"%3d.%03d", hubData.gpsSpeed_bp, hubData.gpsSpeed_ap]];
     [self.frskyHubAltitude setStringValue:[NSString stringWithFormat:@"%3d.%02d", hubData.gpsAltitude_bp, hubData.gpsAltitude_ap]];
     
     [self.frskyHubFuel setStringValue:[NSString stringWithFormat:@"%5u", hubData.fuelLevel]];
     [self.frskyHubRPM setStringValue:[NSString stringWithFormat:@"%5u", hubData.rpm]];
     [self.frskyHubVolts setStringValue:[NSString stringWithFormat:@"%5u", hubData.volts]];
     [self.frskyHubTemp1 setStringValue:[NSString stringWithFormat:@"%5d", hubData.temperature1]];
     [self.frskyHubTemp2 setStringValue:[NSString stringWithFormat:@"%5d", hubData.temperature2]];
     [self.frskyHubBaroAlt setStringValue:[NSString stringWithFormat:@"%5d", hubData.baroAltitude]];

}

- (void) frskyAlarmDataArrivedInCStruct:(struct FrskyAlarmData)
                alarmData forAlarmIndex:(NSInteger)index
{
    switch (index)
    {
        case 0:
            [self.alarmCh2ALevel selectItemAtIndex:alarmData.level];
            [self.alarmCh2AGreater selectItemAtIndex:alarmData.greater];
            [self.alarmCh2AValue setIntValue:alarmData.value];
            [self.alarmCh2AStepper setIntValue:alarmData.value];
            break;
            
        case 1:
            [self.alarmCh2BLevel selectItemAtIndex:alarmData.level];
            [self.alarmCh2BGreater selectItemAtIndex:alarmData.greater];
            [self.alarmCh2BValue setIntValue:alarmData.value];
            [self.alarmCh2BStepper setIntValue:alarmData.value];
            break;
            
        case 2:
            [self.alarmCh1ALevel selectItemAtIndex:alarmData.level];
            [self.alarmCh1AGreater selectItemAtIndex:alarmData.greater];
            [self.alarmCh1AValue setIntValue:alarmData.value];
            [self.alarmCh1AStepper setIntValue:alarmData.value];
            break;
            
        case 3:
            [self.alarmCh1BLevel selectItemAtIndex:alarmData.level];
            [self.alarmCh1BGreater selectItemAtIndex:alarmData.greater];
            [self.alarmCh1BValue setIntValue:alarmData.value];
            [self.alarmCh1BStepper setIntValue:alarmData.value];
    }
}

- (void) telemtryDataStreamStatusChangedTo:(NSInteger) newValue
{
    [self.dataStreamIndicator setIntegerValue:newValue];
}

- (void) telemetryParserBufferLevelNowAt:(NSInteger)byteCount
{
    [self.bufferCount setIntegerValue:byteCount * ([self.bufferCount maxValue] / FRSKY_TELEM_BUFFER_SIZE)];
}

- (void) comboBoxSelectionDidChange:(NSNotification *)notification
{
    // We only have a single combo box in this controller/delegate's care, but we could
    // set an identifier in Interface Builder and ...
    // if ([[[notification object] identifier] isEqualToString:@"serialDeviceList"])
    // {
    [self.telemetryParser closeSerialPort];
    [self.telemetryParser openSerialPort:[
        [self.serialDeviceCombo dataSource] comboBox:self.serialDeviceCombo
                           objectValueForItemAtIndex:[self.serialDeviceCombo indexOfSelectedItem]
                                          ]]; // assume returned objectValue is an NSString
    // }
}

/// DELEGATE METHODS
/////////////////////////////////////




@end
