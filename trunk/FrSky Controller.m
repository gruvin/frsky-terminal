//
//  FrSky Controller.m
//  FrSky Terminal
//
//  Created by Bryan on 28/11/10.
//  Copyright 2010 NZ Hosting Ltd. All rights reserved.
//

#import "FrSky Controller.h"

@implementation FrSky_Controller

#include <stdio.h>   /* Standard input/output definitions */
#include <string.h>  /* String function definitions */
#include <unistd.h>  /* UNIX standard function definitions */
#include <fcntl.h>   /* File control definitions */
#include <errno.h>   /* Error number definitions */
#include <termios.h> /* POSIX terminal control definitions */
#include <stdlib.h>
#include <sys/ioctl.h>

#define DEBUG 0


// Atempt to open the serial port (low level system calls. Seems to work OK.)
- (BOOL)openPort
{
	sprintf(devicePath, "/dev/%s", [[deviceName stringValue] cStringUsingEncoding:NSASCIIStringEncoding]);

	fd = open(devicePath, O_RDWR | O_NOCTTY | O_NONBLOCK);
	if (fd == -1) {
		NSLog(@"Could not open serial device %s", devicePath);
		[userData insertText:[[[NSString alloc] initWithFormat:@"open_port: Unable to open %s", devicePath] autorelease]];
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
	if (fd > 0) close(fd);
	NSLog(@"Serial port closed");
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
				if (packetBuf[0] == 0xfb) [userData insertText:@"ALARM A1a "];
				else if (packetBuf[0] == 0xfc) [userData insertText:@"ALARM A1b "];
				else if (packetBuf[0] == 0xf9) [userData insertText:@"ALARM A2a "];
				else [userData insertText:@"ALARM A2b "];
				
				[userData insertText:[[NSString alloc] initWithFormat:@" - LEVEL:%u GT:%u VAL:%u\n",
									  packetBuf[1], packetBuf[2], packetBuf[3]] ];
			}
			
			// set displayed fields according to data just received
			if (packetBuf[0] == 0xfb) {
				[alarmCh1ALevel selectItemAtIndex:packetBuf[3]];
				[alarmCh1AGreater selectItemAtIndex:packetBuf[2]];
				[alarmCh1AValue setIntValue:packetBuf[1]];
				[alarmCh1AStepper setIntValue:packetBuf[1]];
			} else if (packetBuf[0] == 0xfc) {
				[alarmCh1BLevel selectItemAtIndex:packetBuf[3]];
				[alarmCh1BGreater selectItemAtIndex:packetBuf[2]];
				[alarmCh1BValue setIntValue:packetBuf[1]];
				[alarmCh1BStepper setIntValue:packetBuf[1]];
			} else if (packetBuf[0] == 0xf9) {
				[alarmCh2ALevel selectItemAtIndex:packetBuf[3]];
				[alarmCh2AGreater selectItemAtIndex:packetBuf[2]];
				[alarmCh2AValue setIntValue:packetBuf[1]];
				[alarmCh2AStepper setIntValue:packetBuf[1]];
			} else {
				[alarmCh2BLevel selectItemAtIndex:packetBuf[3]];
				[alarmCh2BGreater selectItemAtIndex:packetBuf[2]];
				[alarmCh2BValue setIntValue:packetBuf[1]];
				[alarmCh2BStepper setIntValue:packetBuf[1]];
			}
			
			break;
			
		case 0xfe: // A1/A2/RSSI values
			[textA1 setIntValue:packetBuf[1]];
			[textA2 setIntValue:packetBuf[2]];
			[textRSSI setIntValue:lastRSSI = (lastRSSI == 0) ? packetBuf[3] : (packetBuf[3] + (lastRSSI*9)) / 10];
			[signalLevel setIntValue:((lastRSSI/2) < 16) ? 16 : lastRSSI / 2];
			break;
			
		case 0xfd: // User Data packet
			if (DEBUG) [userData insertText:@"DATA:"];
			
			switch ([displayMode indexOfSelectedItem]) {
				case 0:
					[userData insertText:[[[NSString alloc] initWithBytes:&packetBuf[3] length:packetBuf[1] 
										encoding:NSASCIIStringEncoding] autorelease]];
					break;
					
				case 1: // HEX
					for (int i=0; i< packetBuf[1]; i++)
						[userData insertText:[[[NSString alloc] initWithFormat:@"<%02x>", (packetBuf[i+3])] autorelease]];
					break;
					
				case 2: // BCD
					for (int i=0; i< packetBuf[1]; i++) {
						[userData insertText:[[[NSString alloc] initWithFormat:@":%1u", ((packetBuf[i+3])&0x0f)] autorelease]];
						[userData insertText:[[[NSString alloc] initWithFormat:@"%1u", (((packetBuf[i+3])&0xf0)>>4)] autorelease]];
					}
					break;
			}
			
			if (DEBUG) [userData insertText:@"\n"];

			break;
			
		case 0: // ignore
			break;
			
		default:
			[userData insertText:[[NSString alloc] 
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

			if (DEBUG) [userData insertText:@"START FRAME "];
			if (DEBUG) [userData insertText:[[NSString alloc] initWithFormat:@"%02x ", c]];

			packetBuf[numPktBytes++] = c;
			dataState = userDataInFrame;
			break;
			
		case userDataInFrame:
			if (c == 0x7d) { 
				dataState = userDataXOR; // XOR next byte
				break; 
			}
			if (c == 0x7e) { // end of frame detected
				if (DEBUG) [userData insertText:@"END FRAME\n"];
				
				[self processPacket:packetBuf];
				
				dataState = userDataIdle;
				break;
			}
			if (DEBUG) [userData insertText:[[NSString alloc] initWithFormat:@"%02x ", c]];
			packetBuf[numPktBytes++] = c;
			break;
			
		case userDataXOR:
			if (DEBUG) [userData insertText:[[NSString alloc] initWithFormat:@"[%02x] ", c ^ 0x20]];
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
		[userData insertText:@"ERROR!: packetBuf overrun!\n\n"];
	}
	
}

-(void)applicationDidFinishLaunching:(NSNotification*)aNotification {
	// There must be a "bindings" method of setting default values. But I don't know it ..
	if ([[deviceName stringValue] isEqualToString:@""])
		[deviceName setStringValue:@"tty.usbserial-FTCDIWIU"];
	self.openPort;

    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.1
							target:self selector:@selector(timerFireMethod:)
							userInfo:nil repeats:YES];
    repeatingTimer = timer;

	[self alarmRefresh:self];
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
		// Need to wait until any currnet timer call compeltes, somehow
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

	self.closePort;
}

- (void)timerFireMethod:(NSTimer*)theTimer
{
	static int timeoutCounter = 0;
	
	timerBusy = YES;
	
	if ((nbytes = read(fd, buffer, 255)) > 0) {
		for(int i = 0; i < nbytes; i++) 
			[self processByte:(unsigned char)buffer[i] ];
	}
	[bufferCount setIntValue:nbytes];
	if (nbytes <= 0) {
		timeoutCounter++;
		if ((timeoutCounter >= 1) && (timeoutCounter < 10))
			[dataStreamIndicator setIntValue:2]; // warning (yellow)
		if (timeoutCounter >= 10) {
			timeoutCounter--; // prevent counter going any higher and eventually wrapping around zero
			[dataStreamIndicator setIntValue:3]; // critical (red)
		}
	} else {
		timeoutCounter = 0;
		[dataStreamIndicator setIntValue:1]; // good (green)
	}
	
	timerBusy = NO;

}

- (IBAction)setSerialDevice:(id)sender
{
	self.closePort;
	self.openPort; // reads the device name from the text box
}

- (IBAction)alarmSetCh1A:(id)sender
{
	unsigned char packet[15];
	int i = 0;
	
	packet[i++] = 0xfb; // Analog 1 alarm 1
	packet[i++] = (unsigned char)[alarmCh1AValue intValue];
	packet[i++] = (unsigned char)[alarmCh1AGreater indexOfSelectedItem];
	packet[i++] = (unsigned char)[alarmCh1ALevel indexOfSelectedItem];
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
	packet[i++] = (unsigned char)[alarmCh1BValue intValue];
	packet[i++] = (unsigned char)[alarmCh1BGreater indexOfSelectedItem];
	packet[i++] = (unsigned char)[alarmCh1BLevel indexOfSelectedItem];
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
	packet[i++] = (unsigned char)[alarmCh2AValue intValue];
	packet[i++] = (unsigned char)[alarmCh2AGreater indexOfSelectedItem];
	packet[i++] = (unsigned char)[alarmCh2ALevel indexOfSelectedItem];
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
	packet[i++] = (unsigned char)[alarmCh2BValue intValue];
	packet[i++] = (unsigned char)[alarmCh2BGreater indexOfSelectedItem];
	packet[i++] = (unsigned char)[alarmCh2BLevel indexOfSelectedItem];
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

- (void) sendPacket:(unsigned char *)packetBuf:(int)length
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
			if (DEBUG) [userData insertText:[[NSString alloc] initWithFormat:@"%02x ", packetBuf[i]]];
		}
		write(fd, frame, 1);
	}
}

@end
