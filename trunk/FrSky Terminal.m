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

// The "new thing", is to make all our outlet object properties and use dot notation (self.blah). There ARE good reasons for it. ;-)

/*
 * Open a serial port file descriptor (fd) using system open() function
 * to obtain granular control of baud rate, stop bits, parity, etc.
*/
- (BOOL) openSerialPort
{
	sprintf(devicePath, "/dev/%s", [[self.serialDeviceCombo objectValueOfSelectedItem] cStringUsingEncoding:NSASCIIStringEncoding]);
    
	fd = open(devicePath, O_RDWR | O_NOCTTY | O_NONBLOCK);
	if (fd == -1) {
		NSLog(@"Could not open serial device %s", devicePath);
		return false;
	} else	{
		NSLog(@"Serial device %s opened OK", devicePath);
		
		struct termios options;
		tcgetattr(fd, &options);
		cfsetispeed(&options, B9600);
		cfsetospeed(&options, B9600);
		options.c_cflag |= (CLOCAL | CREAD);
		options.c_cflag &= ~CSIZE;                          // mask the character size bits
		options.c_cflag |= CS8;                             // 8 data bits
		options.c_cflag &= ~CRTSCTS;                        // diasble hardware flow control
		options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG); // raw input
		options.c_oflag &= ~OPOST;                          // raw output
		options.c_cc[VMIN] = 0;
		options.c_cc[VTIME] = 10;                           // 1 sec timeout
		tcsetattr(fd, TCSANOW, &options);
		return true;
	}
}

- (void) closeSerialPort
{
	if (fd > 0)
    {
        close(fd);
        NSLog(@"Serial port closed");
    }
}

#define PACKET_LINK         0xfe
#define PACKET_USER_DATA    0xfd
#define PACKET_ALARM_A1a    0xfb
#define PACKET_ALARM_A1b    0xfc
#define PACKET_ALARM_A2a    0xf9
#define PACKET_ALARM_A2b    0xfa

// NOTE: packetBuf has been "de-byte-stuffed" already, so 0x7e and 0x7f are decoded to their natural values
- (void) processPacket:(unsigned char *)packetBuf
{
	static unsigned char lastRSSI = 0; // for running average calculation
    
	// process the frame
	switch (packetBuf[0])
	{
		case PACKET_ALARM_A1a:
		case PACKET_ALARM_A1b:
		case PACKET_ALARM_A2a:
		case PACKET_ALARM_A2b:
			if (DEBUG) {
				if (packetBuf[0] == PACKET_ALARM_A1a) NSLog(@"ALARM A1a ");
				else if (packetBuf[0] == PACKET_ALARM_A1b) NSLog(@"ALARM A1b ");
				else if (packetBuf[0] == PACKET_ALARM_A2a) NSLog(@"ALARM A2a ");
				else NSLog(@"ALARM A2b ");
				
				NSLog(@" - LEVEL:%u GT:%u VAL:%u\n",
                      packetBuf[3], packetBuf[2], packetBuf[1]
                      );
			}
			
            // set displayed fields according to data just received
			if (packetBuf[0] == 0xfb) {
				[self.alarmCh1ALevel selectItemAtIndex:packetBuf[3]];
				[self.alarmCh1AGreater selectItemAtIndex:packetBuf[2]];
				[self.alarmCh1AValue setIntValue:packetBuf[1]];
				[self.alarmCh1AStepper setIntValue:packetBuf[1]];
			} else if (packetBuf[0] == 0xfc) {
				[self.alarmCh1BLevel selectItemAtIndex:packetBuf[3]];
				[self.alarmCh1BGreater selectItemAtIndex:packetBuf[2]];
				[self.alarmCh1BValue setIntValue:packetBuf[1]];
				[self.alarmCh1BStepper setIntValue:packetBuf[1]];
			} else if (packetBuf[0] == 0xf9) {
				[self.alarmCh2ALevel selectItemAtIndex:packetBuf[3]];
				[self.alarmCh2AGreater selectItemAtIndex:packetBuf[2]];
				[self.alarmCh2AValue setIntValue:packetBuf[1]];
				[self.alarmCh2AStepper setIntValue:packetBuf[1]];
			} else {
				[self.alarmCh2BLevel selectItemAtIndex:packetBuf[3]];
				[self.alarmCh2BGreater selectItemAtIndex:packetBuf[2]];
				[self.alarmCh2BValue setIntValue:packetBuf[1]];
				[self.alarmCh2BStepper setIntValue:packetBuf[1]];
			}
			break;
			
		case PACKET_LINK: // A1/A2/RSSI values
			[self.textA1 setIntValue:packetBuf[1]];
			[self.textA2 setIntValue:packetBuf[2]];
			[self.textRSSI setIntValue:lastRSSI = (lastRSSI == 0) ? packetBuf[3] :
             (lastRSSI = (packetBuf[3] + ((unsigned int)lastRSSI * 15)) >> 4)]; // averaging filter to prevent RSSI figure from jumping about too much on screen
			[self.signalLevel setIntValue:((lastRSSI/2) < 16) ? 16 : lastRSSI / 2];
			break;
			
		case PACKET_USER_DATA: // User Data packet
            [self.userData setEditable:YES];
            
			if (DEBUG) [self.userData insertText:@"DATA:"];
			
			switch ([self.displayMode indexOfSelectedItem])
            {
				case 0:
					[self.userData insertText:[[NSString alloc] initWithBytes:&packetBuf[3] length:packetBuf[1]
                                                                     encoding:NSASCIIStringEncoding]];
					break;
					
				case 1: // HEX
					for (int i=0; i < packetBuf[1]; i++)
						[self.userData insertText:[NSString stringWithFormat:@"%02x ", (packetBuf[i+3])]];
					break;
					
				case 2: // BCD
					for (int i=0; i < packetBuf[1]; i++) {
						[self.userData insertText:[NSString stringWithFormat:@"%1u", ((packetBuf[i+3])&0x0f)]];
						[self.userData insertText:[NSString stringWithFormat:@":%1u ", (((packetBuf[i+3])&0xf0)>>4)]];
					}
					break;
                    
                case 3: // Fr-Sky Hub packet decoding
                    for (int i=3; i < (3 + (packetBuf[1] & 0x07)); i++)
                    {
                        [self parseTelemHubByte: packetBuf[i]];
                    }
                    break;
			}
			
			if (DEBUG) [self.userData insertText:@"\n"];
            
            [self.userData setEditable:NO];
            
			break;
			
		case 0: // ignore
			break;
			
		default:
			NSLog(@"UNKNWON FRAME TYPE: %x\n", packetBuf[0]);
			
	}
}

// Receive buffer state machine state enum
enum FrSkyDataState {
    STATE_DATA_IDLE,
    STATE_DATA_START,
    STATE_DATA_IN_FRAME,
    STATE_DATA_XOR,
};

#define START_STOP      0x7e
#define BYTE_STUFF      0x7d
#define STUFF_MASK      0x20

#define USER_DATA_BUFFER_SIZE   30

- (void) processByte:(unsigned char) c
{
	static unsigned char packetBuf[USER_DATA_BUFFER_SIZE];
	static int numPktBytes = 0;
	static unsigned char dataState = STATE_DATA_IDLE;
	
	switch (dataState) {
			
		case STATE_DATA_START:
			if (c == START_STOP) break; // Remain in STATE_DATA_START if possible 0x7e,0x7e doublet found.
            
			if (DEBUG) NSLog(@"START FRAME %02x ", c);
            
			packetBuf[numPktBytes++] = c;

			dataState = STATE_DATA_IN_FRAME;
			break;
			
		case STATE_DATA_IN_FRAME:
			if (c == BYTE_STUFF) {
				dataState = STATE_DATA_XOR; // XOR next byte
				break;
			}
			if (c == START_STOP) { // end of frame detected
				if (DEBUG) NSLog(@"END FRAME\n");
				
				[self processPacket:packetBuf];
				
				dataState = STATE_DATA_IDLE;
				break;
			}
			if (DEBUG) NSLog(@"%02x ", c);
			packetBuf[numPktBytes++] = c;
			break;
			
		case STATE_DATA_XOR:
			if (DEBUG) NSLog(@"[%02x] ", c ^ STUFF_MASK);
			packetBuf[numPktBytes++] = c ^ STUFF_MASK;
			dataState = STATE_DATA_IN_FRAME;
			break;
            
		case STATE_DATA_IDLE:
			if (c == START_STOP) {
				numPktBytes = 0;
				dataState = STATE_DATA_START;
			}
			break;
	} // switch
	
	if (numPktBytes > USER_DATA_BUFFER_SIZE) {
		numPktBytes = 0;
		dataState = STATE_DATA_IDLE;
		NSLog(@"OOPS!: packetBuf overrun!"); // TODO: some kind of in program visual flag
	}
	
}

//////////////////////////////////////////////////////
// Start of Fr-Sky Hub Data Processing

- (unsigned char) parseTelemHubIndex: (unsigned char) index
{
    // Bertrand's little trick to point to the right structure element, using only
    // the data-type header code from the Hub packet data
    if (index > 0x26)
        index = 0; // invalid index
    if (index > 0x21)
        index -= 5;
    if (index > 0x0f)
        index -= 6;
    if (index > 0x08)
        index -= 2;
    return 2*(index-1);
}

typedef enum {
    TS_IDLE = 0,  // waiting for 0x5e frame marker
    TS_DATA_ID,   // waiting for dataID
    TS_DATA_LOW,  // waiting for data low byte
    TS_DATA_HIGH, // waiting for data high byte
    TS_XOR = 0x80 // decode stuffed byte
} TS_STATE;

- (void) parseTelemHubByte: (unsigned char) byte
{
    static unsigned char structPos;
    static TS_STATE state = TS_IDLE;
    
    if (byte == 0x5e) {
        state = TS_DATA_ID;
        return;
    }
    if (state == TS_IDLE) {
        return;
    }
    if (state & TS_XOR) {
        byte = byte ^ 0x60;
        state = (TS_STATE)(state - TS_XOR);
    }
    if (byte == 0x5d) {
        state = (TS_STATE)(state | TS_XOR);
        return;
    }
    if (state == TS_DATA_ID) {
        structPos = [self parseTelemHubIndex: byte];
        state = TS_DATA_LOW;
        if (structPos < 0)
            state = TS_IDLE;
        return;
    }
    if (state == TS_DATA_LOW) {
        ((unsigned char *)&frskyHubDataStruct)[structPos] = byte;
        state = TS_DATA_HIGH;
        return;
    }
    
    // state == TS_DATA_HIGH.
    // NOTE: All fields have a high byte, so this state should always be reached (last) when each packet are arrives
    ((unsigned char *)&frskyHubDataStruct)[structPos+1] = byte;
    
    // TODO: Update on-screen data fields from hub data structure
    // This is where a separate "model" object might use delegation or notification to have the View Controller update the display. But nah.
    [self updateFrSkyHubViews];

    state = TS_IDLE;
}

// End of Fr-Sky Hub Data Processing
//////////////////////////////////////////////////////


- (void) sendPacket: (unsigned char *)packetBuf : (int)length
{
    // We can only send serial chars using pointers to buffers. So we need a couple buffered, const chars ...
    char bufBYTE_STUFF = BYTE_STUFF;
    char bufSTART_STOP = START_STOP;
    
	if (fd > 0) {
		write(fd, &bufSTART_STOP, 1);
		for (int i = 0; i < length; i++) {
            if ((packetBuf[i] == START_STOP) || (packetBuf[i] == BYTE_STUFF))
            {
                write(fd, &bufBYTE_STUFF, 1);   // send (insert) byte-stuff char before buffered char
                packetBuf[i] &= ~STUFF_MASK;    // convert 0x7e or 0x7d char to 0x5e or 0x5d
            }
            write(fd, &packetBuf[i], 1);        // send the buffered char
            
			if (DEBUG) NSLog(@"%02x ", packetBuf[i]);
		}
		write(fd, &bufSTART_STOP, 1);
	}
}


- (void) refreshSerialPortsList
{
    // Empty the current list
    [self.serialDeviceCombo removeAllItems];
    
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
    io_object_t     serialPortService;

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
                // Add this device path's base name to the combo box. We'll prepend /dev/ again in openSerialPort:
                [self.serialDeviceCombo addItemWithObjectValue:[NSString stringWithCString:basename(deviceFilePath) encoding:NSUTF8StringEncoding]];
            }
        }
    }
}

- (void) clearUserDataText
{
    [self.userData setEditable:YES]; // this is dumb. shouldn't have to set editable for progrmatic text input!
    [self.userData setString:@""];
    [self.userData setFont:[NSFont fontWithName:@"Monaco" size:12.0]];
    [self.userData setEditable:NO];
}

// TODO: Oh what a mess. (Nothing a bunch of, "refactoring" won't fix ;-)  Unlike the main packet processing
// functions elsewhere in this ever messy coding project, I went and decided to let the Fr-Sky Hub packet data
// get parsed into a C struct (by simply copying source from the openTx project) and later translate that to
// displayed view objects. This method of course is more suitabed to separating the low level comms and packet
// parsing off into its own "Model" class, which I should probably do some day. For now though, it's all in one
// big, messy class and this is the function that would otherwise be a degate. (Not notification, because I do
// want the parsing of and display of packet data to be fully synchornous.)
- (void) updateFrSkyHubViews
{
    char gpsLatitudeDirection = (frskyHubDataStruct.gpsLatitudeNS == ' ') ? '-' : frskyHubDataStruct.gpsLatitudeNS;
    char gpsLongitudeDirection = (frskyHubDataStruct.gpsLongitudeEW == ' ') ? '-' : frskyHubDataStruct.gpsLongitudeEW;
    
    [self.frskyHubLattitude setStringValue:[NSString stringWithFormat:@"%3dº%02d'%02d.%03d %c",
                                            frskyHubDataStruct.gpsLatitude_bp/100,
                                            frskyHubDataStruct.gpsLatitude_bp%100,
                                            frskyHubDataStruct.gpsLatitude_ap * 6 / 1000,
                                            frskyHubDataStruct.gpsLatitude_ap * 6 % 1000,
                                            gpsLatitudeDirection
                                            ]];
    [self.frskyHubLongitude setStringValue:[NSString stringWithFormat:@"%3dº%02d'%02d.%03d %c",
                                            frskyHubDataStruct.gpsLongitude_bp/100,
                                            frskyHubDataStruct.gpsLongitude_bp%100,
                                            frskyHubDataStruct.gpsLongitude_ap * 6 / 1000,
                                            frskyHubDataStruct.gpsLongitude_ap * 6 % 1000,
                                            gpsLongitudeDirection
                                            ]];
    [self.frskyHubHeading setStringValue:[NSString stringWithFormat:@"  %03dº", frskyHubDataStruct.gpsCourse_bp]];
    [self.frskyHubSpeed setStringValue:[NSString stringWithFormat:@"%3d.%03d", frskyHubDataStruct.gpsSpeed_bp, frskyHubDataStruct.gpsSpeed_ap]];
    [self.frskyHubAltitude setStringValue:[NSString stringWithFormat:@"%3d.%02d", frskyHubDataStruct.gpsAltitude_bp, frskyHubDataStruct.gpsAltitude_ap]];
    
    [self.frskyHubFuel setStringValue:[NSString stringWithFormat:@"%5u", frskyHubDataStruct.fuelLevel]];
    [self.frskyHubRPM setStringValue:[NSString stringWithFormat:@"%5u", frskyHubDataStruct.rpm]];
    [self.frskyHubVolts setStringValue:[NSString stringWithFormat:@"%5u", frskyHubDataStruct.volts]];
    [self.frskyHubTemp1 setStringValue:[NSString stringWithFormat:@"%5d", frskyHubDataStruct.temperature1]];
    [self.frskyHubTemp2 setStringValue:[NSString stringWithFormat:@"%5d", frskyHubDataStruct.temperature2]];
    [self.frskyHubBaroAlt setStringValue:[NSString stringWithFormat:@"%5d", -frskyHubDataStruct.baroAltitude]];
}

- (void) applicationDidFinishLaunching:(NSNotification*)aNotification {

    fd = -1; // initialise file-device register to less than zero to prevent problems later
    [self clearUserDataText];
    
    [self refreshSerialPortsList];
    
	[self.serialDeviceCombo setStringValue:@"Select serial port ..."];

    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                      target:self selector:@selector(timerFiredEvent:)
                                                    userInfo:nil repeats:YES];
    repeatingTimer = timer;

	[self alarmRefresh:self];
}

- (void) comboBoxSelectionDidChange:(NSNotification *)notification
{
    [self closeSerialPort];
    [self openSerialPort];
}


// Make the app terminate (quit) if its main window is closed
// NOTE: This delegate call happens AFTER the window has already closed
- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
	return YES;
}

// NOTE: windowsShouldClose doesn't happen if app is directly Quit (as opposed to closing the main window)!
- (BOOL) windowShouldClose:(id)sender
{
	if (repeatingTimer) {
		[repeatingTimer invalidate];
		repeatingTimer = nil;
		// Need to wait until any currnet timer call completes, somehow
        // TODO:Investigate the return value, NSTerminateLater and how it is intended to operate.
		while (timerBusy); // hmmm. Should be OK. :/
	}
	return YES;
}

- (void) applicationWillTerminate:(NSNotification *)aNotification
{
	if (repeatingTimer) {
		[repeatingTimer invalidate];
		repeatingTimer = nil;
        
		// Need to wait until any currnet timer event execution completes, somehow ...
        // TODO:Investigate the return value, NSTerminateLater and how it is intended to operate.
		while (timerBusy); // This seems to do the trick, without issue.
	}

	[self closeSerialPort];
}

- (void) timerFiredEvent:(NSTimer*)theTimer
{
	static int timeoutCounter = 0;
	static BOOL dataStreamLost = NO;
	
	timerBusy = YES;    // used to prevent app quitting while this function is in progress
	
	if ((nbytes = read(fd, buffer, 255)) > 0) {
		for(int i = 0; i < nbytes; i++) 
			[self processByte:(unsigned char)buffer[i] ];
	}
	[self.bufferCount setIntValue:nbytes];
	if (nbytes <= 0) {
		timeoutCounter++;
		if ((timeoutCounter >= 1) && (timeoutCounter < 10))
			[self.dataStreamIndicator setIntValue:2]; // warning (yellow)
		if (timeoutCounter >= 10) {
			timeoutCounter--; // prevent counter going any higher and eventually wrapping around zero
			[self.dataStreamIndicator setIntValue:3]; // critical (red)
            [self.signalLevel setIntValue:0];
			dataStreamLost = YES;
		}
	} else {
		timeoutCounter = 0;
		[self.dataStreamIndicator setIntValue:1]; // good (green)
		if (dataStreamLost) {
			dataStreamLost = NO;
			[self alarmRefresh:self];
		}
	}
	
	timerBusy = NO;

}

- (IBAction) refreshButton:(id)sender {
    [self refreshSerialPortsList];
}

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
	
	[self sendPacket:packet:9];
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
	
	[self sendPacket:packet:9];
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
	
	[self sendPacket:packet:9];
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
	
	[self sendPacket:packet:9];
	
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
	
	[self sendPacket:packet:9];
}

- (IBAction) clearUserData:(id)sender {
    [self clearUserDataText];
}

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


@end
