//
//  Telemetry Parser.m
//  FrSky Terminal
//
//  Created by Bryan on 15/04/13.
//  Copyright (c) 2013 Gruvin. All rights reserved.
//

#import "Telemetry Parser.h"

@implementation Telemetry_Parser
{
}

/**************
 ** I N I T  **
 **************/
- (id) init
{
    self = [super init];
    if (self)
    {
        _serialPortFileDescriptor = -1;
    }
    return self;
}

- (void) dealloc
{
    if (dataPollingTimer) {
        [dataPollingTimer invalidate];
        dataPollingTimer = nil;
        
        // Need to wait until any currnet timer event execution completes, somehow -- because it's in a
        // separate thread and code could stil be executing when our app goes away!
        while (dataPollingTimerEventInProgress); // This seems to do the trick. But I think it's a little ugly.
        // TODO:Investigate the return value, NSTerminateLater and how it is intended to operate.
    }
    // ARC will call [super dealloc]
}

/*
* Open a serial port file descriptor (fd) using system open() function
* to obtain granular control of baud rate, stop bits, parity, etc.
*/
#define DEVICE_PATH_BUFFER_SIZE 1024
- (BOOL) openSerialPort:  (NSString *)deviceName
{
    BOOL portOpenedOK = NO;

    char devicePath[DEVICE_PATH_BUFFER_SIZE];
	snprintf(devicePath,
             DEVICE_PATH_BUFFER_SIZE - strlen("/dev/"), // prevent buffer overflow
             "/dev/%s", [deviceName cStringUsingEncoding:NSASCIIStringEncoding]);
    
    
	_serialPortFileDescriptor = open(devicePath, O_RDWR | O_NOCTTY | O_NONBLOCK);
	if (_serialPortFileDescriptor == -1) {
		NSLog(@"Could not open serial device %s", devicePath);
	}
    else
    {
		struct termios options;
		tcgetattr(_serialPortFileDescriptor, &options);
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
		tcsetattr(_serialPortFileDescriptor, TCSANOW, &options);

		NSLog(@"Serial device %s opened OK", devicePath);
        
		portOpenedOK = YES;
	}
    
    if (portOpenedOK) // set up pollingTimer
    {
        
        // Initialise timer based polling for incoming serial data
        dataPollingTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                          target:self selector:@selector(dataPollingEvent:)
                                                        userInfo:nil repeats:YES];
    }

    return portOpenedOK;
    
}

- (void) closeSerialPort
{
	if (_serialPortFileDescriptor > 0)
    {
        close(_serialPortFileDescriptor);
        NSLog(@"Serial port closed");
    }
}

- (void) dataPollingEvent: (NSTimer *) theTimer
{
	static int timeoutCounter = 0;
	
	dataPollingTimerEventInProgress = YES;    // used to prevent app quitting while this function is in progress
	
    int nbytes;
	if ((nbytes = read(_serialPortFileDescriptor, _telemetryDataBuffer, FRSKY_TELEM_BUFFER_SIZE)) > 0)
    {
        // parse all bytes thus far received ...
		for(int i = 0; i < nbytes; i++)
			[self parseTelemetryByte:(unsigned char)_telemetryDataBuffer[i] ];
	}
    
	_telemetryDataBufferUsage = nbytes;
    
	if (nbytes == 0)
    {
		timeoutCounter++;

		if ((timeoutCounter >= 1) && (timeoutCounter < 10))
			_telemtryDataStreamStatus = 2;    // pause in data stream detected

		if (timeoutCounter >= 10)
        {
			timeoutCounter--; // prevent counter going any higher and eventually wrapping around zero
			_telemtryDataStreamStatus = 3;    // data stream has stopped (for too long)
		}
	}
    else
    {
		timeoutCounter = 0;
		_telemtryDataStreamStatus = 1;        // data stream is flowing nicely
	}
	
	dataPollingTimerEventInProgress = NO;
}


/*
 * Each telemtry bytes received is sent through this state machine, in turn.
 * Eventually, we expect to have built a complete Fr-Sky telemetry data packet,
 * which is this handed off (synchornously) to parseFrskyPacket:withByteCount:
 */
- (void) parseTelemetryByte: (unsigned char)thisByte
{
    int numPktBytes;
    static unsigned char packetBuffer[FRSKY_TELEM_BUFFER_SIZE];
    static int packetByteCount;
    
    static FRSKY_DATA_STATE dataState = IDLE;
    
    switch (dataState)
    {
        case START:
            if (thisByte == TELEM_START_STOP) break; // Remain in userDataStart if possible 0x7e,0x7e doublet found.
            
            if (numPktBytes < FRSKY_RX_PACKET_SIZE)
                packetBuffer[packetByteCount++] = thisByte;
            
            dataState = IN_FRAME;
            break;
            
        case IN_FRAME:
            if (thisByte == TELEM_BYTE_STUFF)
            {
                dataState = XOR;                // XOR next byte
                break;
            }
            if (thisByte == TELEM_START_STOP)    // end of frame detected
            {
                [self parseFrskyPacket: packetBuffer withByteCount:packetByteCount];
                dataState = IDLE;
                break;
            }
            if (numPktBytes < FRSKY_RX_PACKET_SIZE)
                packetBuffer[packetByteCount++] = thisByte;
            break;
            
        case XOR:
            if (numPktBytes < FRSKY_RX_PACKET_SIZE)
                packetBuffer[packetByteCount++] = thisByte ^ TELEM_STUFF_MASK;
            dataState = IN_FRAME;
            break;
            
        case IDLE:
            if (thisByte == TELEM_START_STOP)
            {
                packetByteCount = 0;
                dataState = START;
            }
            break;
            
    }
}

/*
 * Each complete Fr-Sky telemtry data packet is sent there for decoding and
 * storing of its contained data. In the case of a User Data packet (data sent
 * into the RC receiver's User Data port at 9600 Baud) the data in said packet
 * is sent off to parseTelemHubByte: for parsing, one byte at a time.
 */
- (void) parseFrskyPacket: (unsigned char *)packetBuffer withByteCount: (int) byteCount
{
    // What type of packet?
    switch (packetBuffer[0])
    {
        case TELEM_PKT_TYPE_A1A:
        case TELEM_PKT_TYPE_A1B:
        case TELEM_PKT_TYPE_A2A:
        case TELEM_PKT_TYPE_A2B:
        {
            struct FrskyAlarmData *alarmptr;
            
            // set alarmptr to address of _frskyAlarmsStruct[n],
            // where n is derived from the packet type in packetBuffer[0]
            alarmptr = &_frskyAlarmsStruct[(packetBuffer[0]-TELEM_PKT_TYPE_A2B/*0xf9*/)];
            alarmptr->value = packetBuffer[1];
            alarmptr->greater = packetBuffer[2] & 0x01;
            alarmptr->level = packetBuffer[3] & 0x03;
        }
            break;
            
        case TELEM_PKT_TYPE_LINK: // A1/A2/RSSI[1/2] values
            _frskyLinkData.frskyA1Value = packetBuffer[1];
            _frskyLinkData.frskyA2Value = packetBuffer[2];
            _frskyLinkData.frskyRSSI1 = packetBuffer[3];
            _frskyLinkData.frskyRSSI2 = packetBuffer[4];

            // Call delegate's frskyLinkDataArrivedInCStruct: (if it exists) to have something done with this new data
            if ([self.delegate respondsToSelector:@selector(frskyLinkDataArrivedInCStruct:)] )
            {
                [self.delegate frskyLinkDataArrivedInCStruct: _frskyLinkData];
            }
            
            break;
            

        case TELEM_PKT_TYPE_USER:   // User Data packet
        {
            int numBytes = 3 + (packetBuffer[1] & 0x07); // sanitize in case of data corruption leading to buffer overflow
            

            // Ask our delegate if we shoul dbe processing Fr-Sky Hub data or not, at the moment
            if ([self.delegate telemetryParserShouldProcessFrskyHubData]) // this one is a required protocol method. So not checking for responder.
            {
                for (int i=3; i < numBytes; i++)
                {
                    [self parseTelemHubByte: packetBuffer[i] ];
                }
            }
            else
            {
                // Call delegate's frskyUserDataArrivedInString: (if it exists) to have something done with this new data
                if ([self.delegate respondsToSelector:@selector(frskyUserDataArrivedInString:)] )
                {
                    [self.delegate frskyUserDataArrivedInString: [[NSString alloc] initWithBytes:packetBuffer length:numBytes encoding:NSASCIIStringEncoding]];
                }
            }
        }
            break;

    }

}

unsigned char
computeTelemHubIndex(unsigned char index)
{
/*
    This is the openTx project's trick to point to the right structure element, using 
    only the data-type header code from the Fr-Sky hub packet data. It just saves
    code resource on the 8-bit controller and is copied here, verbatim.
*/
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

/*
 * This state machine parses a single byte of Fr-Sky telemetry User Data, from parseFrskyPacket:withByteCount:.
 * When a complete Fr-Sky hub data packet is received, a delegate function is called, passwing the packet
 * data for processing elsewhere.
 */
- (void) parseTelemHubByte: (unsigned char) thisByte
{
    static unsigned char structPos;
    static HUB_DATA_STATE state = TS_IDLE;
    
    if (thisByte == 0x5e) {
        state = TS_DATA_ID;
        return;
    }
    if (state == TS_IDLE) {
        return;
    }
    if (state & TS_XOR) {
        thisByte = thisByte ^ 0x60;
        state = (HUB_DATA_STATE)(state - TS_XOR);
    }
    if (thisByte == 0x5d) {
        state = (HUB_DATA_STATE)(state | TS_XOR);
        return;
    }
    if (state == TS_DATA_ID) {
        structPos = computeTelemHubIndex(thisByte);
        state = TS_DATA_LOW;
        if (structPos < 0)
            state = TS_IDLE;
        return;
    }
    if (state == TS_DATA_LOW) {
        ((unsigned char *)&_frskyHubDataStruct)[structPos] = thisByte;
        state = TS_DATA_HIGH;
        return;
    }
    
    // else, state == TS_DATA_HIGH
    // All fields have a high byte, so this state should always be reached, once each packet has fully arrived
    ((unsigned char *)&_frskyHubDataStruct)[structPos+1] = thisByte;    // store the data byte in the struct
    

    // Call delegate's function to do something with this new data
    if ([self.delegate respondsToSelector:@selector(frskyHubDataArrivedInCStruct:)] )
    {
        [self.delegate frskyHubDataArrivedInCStruct: _frskyHubDataStruct];
    }

    
    state = TS_IDLE;
    
}

- (void) sendPacket: (unsigned char *)packetBuf : (int)length
{
    // We can only send serial chars using pointers to buffers. So we need a couple buffered, const chars ...
    char bufBYTE_STUFF = TELEM_BYTE_STUFF;
    char bufSTART_STOP = TELEM_START_STOP;
    
	if (_serialPortFileDescriptor > 0) {
		write(_serialPortFileDescriptor, &bufSTART_STOP, 1);
		for (int i = 0; i < length; i++) {
            if ((packetBuf[i] == TELEM_START_STOP) || (packetBuf[i] == TELEM_BYTE_STUFF))
            {
                write(_serialPortFileDescriptor, &bufBYTE_STUFF, 1);   // send (insert) byte-stuff char before buffered char
                packetBuf[i] &= ~TELEM_STUFF_MASK;    // convert 0x7e or 0x7d char to 0x5e or 0x5d
            }
            write(_serialPortFileDescriptor, &packetBuf[i], 1);        // send the buffered char
           
		}
		write(_serialPortFileDescriptor, &bufSTART_STOP, 1);
	}
}

@end
