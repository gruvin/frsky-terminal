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

@synthesize userData = _userData;
@synthesize serialDeviceCombo = _serialDeviceCombo;

@synthesize myLabel =_myLabel;
@synthesize textA1 = _textA1;
@synthesize textA2 = _textA2;
@synthesize textRSSI = _textRSSI;
@synthesize signalLevel = _signalLevel;
@synthesize bufferCount = _bufferCount;
@synthesize dataStreamIndicator = _dataStreamIndicator;
@synthesize displayMode = _displayMode;

@synthesize alarmCh1ALevel = _alarmCh1ALevel;
@synthesize alarmCh1BLevel = _alarmCh1BLevel;
@synthesize alarmCh2ALevel = _alarmCh2ALevel;
@synthesize alarmCh2BLevel = _alarmCh2BLevel;
@synthesize alarmCh1AGreater = _alarmCh1AGreater;
@synthesize alarmCh1BGreater = _alarmCh1BGreater;
@synthesize alarmCh2AGreater = _alarmCh2AGreater;
@synthesize alarmCh2BGreater = _alarmCh2BGreater;
@synthesize alarmCh1AValue = _alarmCh1AValue;
@synthesize alarmCh1BValue = _alarmCh1BValue;
@synthesize alarmCh2AValue = _alarmCh2AValue;
@synthesize alarmCh2BValue = _alarmCh2BValue;
@synthesize alarmCh1AStepper = _alarmCh1AStepper;
@synthesize alarmCh1BStepper = _alarmCh1BStepper;
@synthesize alarmCh2AStepper = _alarmCh2AStepper;
@synthesize alarmCh2BStepper = _alarmCh2BStepper;



///////////////////////////////
///// C UTILITY FUNCTIONS /////

static kern_return_t findSerialPorts(io_iterator_t *matchingServices)
{
    kern_return_t       kernResult;
    mach_port_t         masterPort;
    CFMutableDictionaryRef  classesToMatch;
    
    kernResult = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (KERN_SUCCESS != kernResult)
    {
        printf("ERROR: IOMasterPort returned %d\n", kernResult);
    }
    else {
        
        // Serial devices are instances of class IOSerialBSDClient.
        classesToMatch = IOServiceMatching(kIOSerialBSDServiceValue);
        if (classesToMatch == NULL)
        {
            printf("ERROR: IOServiceMatching returned a NULL dictionary.\n");
        }
        else {
            CFDictionarySetValue(classesToMatch,
                                 CFSTR(kIOSerialBSDTypeKey),
                                 CFSTR(kIOSerialBSDRS232Type));
        }
        
        kernResult = IOServiceGetMatchingServices(masterPort, classesToMatch, matchingServices);
        if (KERN_SUCCESS != kernResult)
        {
            printf("IOServiceGetMatchingServices returned %d\n", kernResult);
        }
    }
    
    return kernResult;
}
///// END C UTILITY FUNCTIONS /////
///////////////////////////////////


// Atempt to open the serial port (low level system calls. Seems to work OK.)
- (BOOL)openPort
{
	sprintf(devicePath, "/dev/%s", [[self.serialDeviceCombo itemObjectValueAtIndex:[self.serialDeviceCombo indexOfSelectedItem]] cStringUsingEncoding:NSASCIIStringEncoding]);
    
	fd = open(devicePath, O_RDWR | O_NOCTTY | O_NONBLOCK);
	if (fd == -1) {
		NSLog(@"Could not open serial device %s", devicePath);
		[self.userData insertText:[[NSString alloc] initWithFormat:@"open_port: Unable to open %s", devicePath]];
		return false;
	} else	{
		NSLog(@"Serial port opened OK on %s", devicePath);
		
		// fcntl not needed due to O_NONBLOCK arg in open() above
		// fcntl(fd, F_SETFL, FNDELAY); // no delay. return 0 if nothing in buffer
		
		struct termios options;
		tcgetattr(fd, &options);
		cfsetispeed(&options, B9600);
		cfsetospeed(&options, B9600);
		options.c_cflag |= (CLOCAL | CREAD);
		options.c_cflag &= ~CSIZE; /* Mask the character size bits */
		options.c_cflag |= CS8;    /* Select 8 data bits */
		options.c_cflag &= ~CRTSCTS; // diasble hardware flow control
		options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG); // raw input
		options.c_oflag &= ~OPOST; // raw output (just in case we do some output)
		options.c_cc[VMIN] = 0;
		options.c_cc[VTIME] = 10;     // 1 sec timeout
		tcsetattr(fd, TCSANOW, &options);
		return true;
	}
}

- (void) closePort
{
	if (fd > 0)
    {
        close(fd);
        NSLog(@"Serial port closed");
    }
}

// NOTE: packetBuf should not contain start/end 0x7e's
- (void) processPacket:(unsigned char *)packetBuf
{
	static unsigned char lastRSSI = 0; // for running average calculation
    
	// process the frame
	switch (packetBuf[0])
	{
		case 0xf9:
		case 0xfa:
		case 0xfb:
		case 0xfc:
			if (DEBUG) {
				if (packetBuf[0] == 0xfb) NSLog(@"ALARM A1a ");
				else if (packetBuf[0] == 0xfc) NSLog(@"ALARM A1b ");
				else if (packetBuf[0] == 0xf9) NSLog(@"ALARM A2a ");
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
			
		case 0xfe: // A1/A2/RSSI values
			[self.textA1 setIntValue:packetBuf[1]];
			[self.textA2 setIntValue:packetBuf[2]];
			[self.textRSSI setIntValue:lastRSSI = (lastRSSI == 0) ? packetBuf[3] :
             (lastRSSI = (packetBuf[3] + ((unsigned int)lastRSSI * 15)) >> 4)];
			[self.signalLevel setIntValue:((lastRSSI/2) < 16) ? 16 : lastRSSI / 2];
			break;
			
		case 0xfd: // User Data packet
			if (DEBUG) [self.userData insertText:@"DATA:"];
			
			switch ([self.displayMode indexOfSelectedItem]) {
				case 0:
					[self.userData insertText:[[NSString alloc] initWithBytes:&packetBuf[3] length:packetBuf[1]
                                                                     encoding:NSASCIIStringEncoding]];
					break;
					
				case 1: // HEX
					for (int i=0; i< packetBuf[1]; i++)
						[self.userData insertText:[[NSString alloc] initWithFormat:@"<%02x>", (packetBuf[i+3])]];
					break;
					
				case 2: // BCD
					for (int i=0; i< packetBuf[1]; i++) {
						[self.userData insertText:[[NSString alloc] initWithFormat:@":%1u", ((packetBuf[i+3])&0x0f)]];
						[self.userData insertText:[[NSString alloc] initWithFormat:@"%1u", (((packetBuf[i+3])&0xf0)>>4)]];
					}
					break;
			}
			
			if (DEBUG) [self.userData insertText:@"\n"];
            
			break;
			
		case 0: // ignore
			break;
			
		default:
			[self.userData insertText:[[NSString alloc]
                                       initWithFormat:@"UNKNWON FRAME TYPE: %x\n",
                                       packetBuf[0]] ];
			
	}
}

// Receive buffer state machine defs
#define userDataIdle	0
#define userDataStart	1
#define userDataInFrame 2
#define userDataXOR		3

- (void) processByte:(unsigned char) c
{
	static unsigned char packetBuf[30];
	static int numPktBytes = 0;
	static unsigned char dataState = userDataIdle;
	
	switch (dataState) {
			
		case userDataStart:
			if (c == 0x7e) break; // Remain in userDataStart if possible 0x7e,0x7e doublet found.
            
			if (DEBUG) [self.userData insertText:@"START FRAME "];
			if (DEBUG) [self.userData insertText:[[NSString alloc] initWithFormat:@"%02x ", c]];
            
			packetBuf[numPktBytes++] = c;
			dataState = userDataInFrame;
			break;
			
		case userDataInFrame:
			if (c == 0x7d) {
				dataState = userDataXOR; // XOR next byte
				break;
			}
			if (c == 0x7e) { // end of frame detected
				if (DEBUG) [self.userData insertText:@"END FRAME\n"];
				
				[self processPacket:packetBuf];
				
				dataState = userDataIdle;
				break;
			}
			if (DEBUG) [self.userData insertText:[[NSString alloc] initWithFormat:@"%02x ", c]];
			packetBuf[numPktBytes++] = c;
			break;
			
		case userDataXOR:
			if (DEBUG) [self.userData insertText:[[NSString alloc] initWithFormat:@"[%02x] ", c ^ 0x20]];
			packetBuf[numPktBytes++] = c ^ 0x20;
			dataState = userDataInFrame;
			break;
            
		case userDataIdle:
			if (c == 0x7e) {
				numPktBytes = 0;
				dataState = userDataStart;
			}
			break;
	} // switch
	
	if (numPktBytes > 30) {
		numPktBytes = 0;
		dataState = userDataIdle;
		[self.userData insertText:@"ERROR!: packetBuf overrun!\n\n"];
	}
	
}

- (void) sendPacket: (unsigned char *)packetBuf : (int)length
{
	unsigned char stuff7e[2] = {0x7d,0x5e};
	unsigned char stuff7d[2] = {0x7d,0x5d};
	unsigned char frame[1] = {0x7e};
	
	if (fd > 0) {
		write(fd, frame, 1);
		for (int i = 0; i < length; i++) {
			if (packetBuf[i] == 0x7e) write(fd, stuff7e, 2);
			else if (packetBuf[i] == 0x7d) write(fd, stuff7d, 2);
			else write(fd, (packetBuf+i), 1);
			if (DEBUG) [self.userData insertText:[[NSString alloc] initWithFormat:@"%02x ", packetBuf[i]]];
		}
		write(fd, frame, 1);
	}
}


-(void)refreshSerialPortsList
{
    // Empty the current list
    [self.serialDeviceCombo removeAllItems];
    
    // Ask IOKit for a list (dictionary) of available serial ports
    io_iterator_t   serialPortIterator;
    kern_return_t   kernResult;
    char        deviceFilePath[1024];
    
    kernResult = findSerialPorts(&serialPortIterator);
    
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
            CFRelease(deviceFilePathAsCFString);
            
            if (result)
            {
                // Add this device path's base name only, to the combo box (we'll prepend /dev/ again in openPort:)
                [self.serialDeviceCombo addItemWithObjectValue:[NSString stringWithCString:basename(deviceFilePath) encoding:NSUTF8StringEncoding]];
            }
        }
    }
}

-(void)applicationDidFinishLaunching:(NSNotification*)aNotification {

    fd = -1; // initialise file-device register to less than zero to prevent problems later

    [self refreshSerialPortsList];
    
	[self.serialDeviceCombo setStringValue:@"Select serial port ..."];

    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.1
							target:self selector:@selector(timerFireMethod:)
							userInfo:nil repeats:YES];
    repeatingTimer = timer;

	[self alarmRefresh:self];
}

-(void)comboBoxSelectionDidChange:(NSNotification *)notification
{
    [self closePort];
    [self openPort];
}


// Make the app terminate (quit) if its main window is closed
// NOTE: This delegate call happens AFTER the window has already closed
- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
	return YES;
}

// NOTE: windowsShouldClose doesn't happen if app is directly Quit (as opposed to closing the main window)!
- (BOOL)windowShouldClose:(id)sender
{
	if (repeatingTimer) {
		[repeatingTimer invalidate];
		repeatingTimer = nil;
		// Need to wait until any currnet timer call completes, somehow
		while (timerBusy); // hmmm. Should be OK. :/
	}
	return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	if (repeatingTimer) {
		[repeatingTimer invalidate];
		repeatingTimer = nil;
		// Need to wait until any currnet timer call compeltes, somehow
		while (timerBusy); // hmmm. Should be OK. :/
	}

	[self closePort];
}

- (void)timerFireMethod:(NSTimer*)theTimer
{
	static int timeoutCounter = 0;
	static BOOL dataStreamLost = NO;
	
	timerBusy = YES;
	
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

- (IBAction)refreshButton:(id)sender {
    [self refreshSerialPortsList];
}

- (IBAction)alarmSetCh1A:(id)sender
{
	unsigned char packet[15];
	int i = 0;
	
	packet[i++] = 0xfb; // Analog 1 alarm 1
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

- (IBAction)alarmSetCh1B:(id)sender
{
	unsigned char packet[15];
	int i = 0;
	
	packet[i++] = 0xfc; // Analog 1 alarm 2
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

- (IBAction)alarmSetCh2A:(id)sender
{
	unsigned char packet[15];
	int i = 0;
	
	packet[i++] = 0xf9; // Analog 2 alarm 1
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

- (IBAction)alarmSetCh2B:(id)sender
{
	unsigned char packet[15];
	int i = 0;
	
	packet[i++] = 0xfa; // Analog 2 alarm 2
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

- (IBAction)alarmRefresh:(id)sender
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


@end
