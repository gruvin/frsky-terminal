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

@implementation FrSky_Terminal

// All our view property objects are auto-synthesized in Xcode 4. No need to labourously do that ourselves here, thank, umm Steve? :-P


- (void) refreshSerialPortsList
{
    // Empty the current list
    [self.serialDeviceCombo removeAllItems];
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////
    // TODO: Refactor to model. Then maybe use the datasource mechanism to populate combo box?
    //       Or just have the system level stuff moved to the model, call that and
    //       then just pull the list back here in an array or dict, I guess. Easier.

    // Ask IOKit for a list (dictionary) of available serial ports
    io_iterator_t   serialPortIterator;
    kern_return_t   kernResult;
    char        deviceFilePath[1024];
    
    mach_port_t         masterPort;
    CFMutableDictionaryRef  classesToMatch;
    
    kernResult = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (KERN_SUCCESS != kernResult)
    {
        NSLog(@"ERROR: IOMasterPort returned error code %d, during serial port device look-up", kernResult);
        return;
    }
    
    // Serial devices are instances of class IOSerialBSDClient.
    classesToMatch = IOServiceMatching(kIOSerialBSDServiceValue);
    if (classesToMatch == NULL)
    {
        NSLog(@"ERROR: IOServiceMatching returned a NULL dictionary, during serial port device look-up (no serial ports available?)");
        return;
    }
    CFDictionarySetValue(classesToMatch,
                         CFSTR(kIOSerialBSDTypeKey),
                         CFSTR(kIOSerialBSDRS232Type));

    kernResult = IOServiceGetMatchingServices(masterPort, classesToMatch, &serialPortIterator);
    if (KERN_SUCCESS != kernResult)
    {
        NSLog(@"IOServiceGetMatchingServices returned error code %d, during serial port device look-up", kernResult);
        return;
    }

    deviceFilePath[0] = '\0';
    io_object_t serialPortService;

    // Load the file paths of all available serial ports from the dictionary into our port combobox
    while ((serialPortService = IOIteratorNext(serialPortIterator)))
    {
        // obtain this device's file path from its IOCallOut property
        CFTypeRef   deviceFilePathAsCFString;
        deviceFilePathAsCFString = IORegistryEntryCreateCFProperty(serialPortService,
                                                                   CFSTR(kIOCalloutDeviceKey),
                                                                   kCFAllocatorDefault,
                                                                   0);
        
        if (deviceFilePathAsCFString) // if we got a string ...
        {
            Boolean result = CFStringGetCString(deviceFilePathAsCFString,
                                                deviceFilePath,
                                                sizeof(deviceFilePath),
                                                kCFStringEncodingASCII);
            CFRelease(deviceFilePathAsCFString);    // free the memory allocated by CFStringGetCString
            
            if (result)
            {
                // TODO: This should update local model data only
                // Add this device path's base name to the combo box. We'll prepend /dev/ again in openSerialPort:
                [self.serialDeviceCombo addItemWithObjectValue:[NSString stringWithCString:basename(deviceFilePath) encoding:NSUTF8StringEncoding]];
            }
        }
    }
    // END TODO
    ///////////////////////////////////////////////////////////////////////////////////////////////////
   
}

// TODO: refactor to call a model method
- (IBAction) refreshButton:(id)sender {
    [self refreshSerialPortsList];
}


- (void) clearUserDataText
{
    [self.userData setEditable:YES]; // this is dumb. shouldn't have to set editable for progrmatic text input!
    [self.userData setString:@""];
    [self.userData setFont:[NSFont fontWithName:@"Monaco" size:12.0]];
    [self.userData setEditable:NO];
}

- (void) applicationDidFinishLaunching:(NSNotification*)aNotification {

    telemetryParser = [[Telemetry_Parser alloc] init];
    [telemetryParser setDelegate:self]; // make us the delegate for telemetryParser's FrskyParserDelegate protocol methods 
    
    [self clearUserDataText];   // to set font, etc
    
    [self refreshSerialPortsList];
    
	[self.serialDeviceCombo setStringValue:@"Select serial port ..."];

	// [self alarmRefresh:self];
}

- (void) comboBoxSelectionDidChange:(NSNotification *)notification
{
    [telemetryParser closeSerialPort];
    [telemetryParser openSerialPort:[self.serialDeviceCombo objectValueOfSelectedItem]]; // assume the object is an NSString
}


// Make the app terminate (quit) if its main window is closed
// NOTE: This delegate call happens AFTER the window has already closed
- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
	return YES;
}

// TODO: Is this needed -- or is applicationWillTerminate sufficient on its own?
// NOTE: windowsShouldClose doesn't happen if app is directly Quit (as opposed to closing the main window)!
- (BOOL) windowShouldClose:(id)sender
{
    [telemetryParser closeSerialPort];
	return YES;
}

- (void) applicationWillTerminate:(NSNotification *)aNotification
{
	[telemetryParser closeSerialPort];
}

- (IBAction) clearUserData:(id)sender {
    [self clearUserDataText];
}

// Change views (if needed) when a different data display mode is selected
- (IBAction) dataModeSelected:(id)sender {
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

/******************************/
/** BEGIN DELEGATE FUNCTIONS **/
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
    
    // TODO: These two UI aesthetic view functions should really be in delegate function, called when they get updated in the model
    [self.dataStreamIndicator setIntegerValue:(255/*IB max value*/ / FRSKY_TELEM_BUFFER_SIZE) * telemetryParser.telemtryDataStreamStatus];
    [self.bufferCount setIntegerValue:telemetryParser.telemetryDataBufferUsage];
    
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
     [self.frskyHubBaroAlt setStringValue:[NSString stringWithFormat:@"%5d", -hubData.baroAltitude]];

}

/**  END DELEGATE FUNCTIONS  **/
/******************************/


/*** TODO: Refactor all these ugly alarm set functions and move them to the model ****/
- (IBAction) alarmSetCh1A:(id)sender
{
	unsigned char packet[15];
	int i = 0;
	
	packet[i++] = 0xfb; // A1 alarm A
	packet[i++] = (unsigned char)[self.alarmCh1AValue intValue];
	packet[i++] = (unsigned char)[self.alarmCh1AGreater indexOfSelectedItem];
	packet[i++] = (unsigned char)[self.alarmCh1ALevel indexOfSelectedItem];
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	
	[telemetryParser sendPacket:packet:9];
}

- (IBAction) alarmSetCh1B:(id)sender
{
	unsigned char packet[15];
	int i = 0;
	
	packet[i++] = 0xfc; // A1 alarm B
	packet[i++] = (unsigned char)[self.alarmCh1BValue intValue];
	packet[i++] = (unsigned char)[self.alarmCh1BGreater indexOfSelectedItem];
	packet[i++] = (unsigned char)[self.alarmCh1BLevel indexOfSelectedItem];
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	
	[telemetryParser sendPacket:packet:9];
}

- (IBAction) alarmSetCh2A:(id)sender
{
	unsigned char packet[15];
	int i = 0;
	
	packet[i++] = 0xf9; // A2 alarm A
	packet[i++] = (unsigned char)[self.alarmCh2AValue intValue];
	packet[i++] = (unsigned char)[self.alarmCh2AGreater indexOfSelectedItem];
	packet[i++] = (unsigned char)[self.alarmCh2ALevel indexOfSelectedItem];
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	
	[telemetryParser sendPacket:packet:9];
}

- (IBAction) alarmSetCh2B:(id)sender
{
	unsigned char packet[15];
	int i = 0;
	
	packet[i++] = 0xfa; // A2 alarm B
	packet[i++] = (unsigned char)[self.alarmCh2BValue intValue];
	packet[i++] = (unsigned char)[self.alarmCh2BGreater indexOfSelectedItem];
	packet[i++] = (unsigned char)[self.alarmCh2BLevel indexOfSelectedItem];
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	
	[telemetryParser sendPacket:packet:9];
	
}

- (IBAction) alarmRefresh:(id)sender
{
	unsigned char packet[15];
	int i = 0;
	
	packet[i++] = 0xf8;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	
	[telemetryParser sendPacket:packet:9];
}


@end
