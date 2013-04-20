//
//  Telemetry Parser.m
//  FrSky Terminal
//
//  Created by Bryan on 15/04/13.
//  Copyright (c) 2013 Gruvin. All rights reserved.
//

#import "Telemetry Parser.h"

@implementation TelemetryParser

/**************
 ** I N I T  **
 **************/
- (id) init
{
    self = [super init];
    if (self)
    {
        [self refreshSerialDeviceList];
    }
    return self;
}

// Custom property setter to effect delgate call when value changes
- (void) setTelemtryDataStreamStatus:(NSInteger) newValue
{
    _telemtryDataStreamStatus = newValue;

    // Notify delegate of that the value has changed
    if ([self.delegate respondsToSelector:@selector(telemtryDataStreamStatusChangedTo:)] )
    {
        [self.delegate telemtryDataStreamStatusChangedTo:_telemtryDataStreamStatus ];
    }
}

// Custom property setter to effect delgate call when value changes
- (void) setTelemetryDataBufferUsage:(NSInteger) byteCount
{
    _telemetryDataBufferUsage = byteCount;

    // Notify delegate of that the value has changed
    if ([self.delegate respondsToSelector:@selector(telemetryParserBufferLevelNowAt:)] )
    {
        [self.delegate telemetryParserBufferLevelNowAt:_telemetryDataBufferUsage ];
    }
}

- (void) refreshSerialDeviceList
{
    // start with empty array
    NSMutableArray *devices = [[NSMutableArray alloc] init];
    
    // Ask IOKit for a list (dictionary) of available serial ports
    io_iterator_t   serialPortIterator;
    kern_return_t   kernResult;
    char            deviceFilePath[1024];
    
    mach_port_t     masterPort;
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
                [devices addObject:[NSString stringWithCString:basename(deviceFilePath) encoding:NSUTF8StringEncoding]];
            }
        }
    }

    _serialDevicesList = devices;
}

////////////////////////////////////////////
/// NSComboBoxDataSource methods
- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
    return [self.serialDevicesList count];
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index
{
    return [self.serialDevicesList objectAtIndex:index];
}
////////////////////////////////////////////


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
    
    if (portOpenedOK)
    {
 
        // Initialise timer-based polling, for incoming serial data
        _dataPollingTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                             target:self selector:@selector(dataPollingEvent:)
                                                           userInfo:nil repeats:YES];
    }

    return portOpenedOK;
    
}

- (void) closeSerialPort
{

    // Stop the dataPolling timer
    if (_dataPollingTimer) {
        
        [_dataPollingTimer invalidate];
        _dataPollingTimer = nil;
        
        // Need to wait until any current dataPollingEvent: execution completes, because it's in a
        // separate thread and could return after we're gone! (I think?)
        while (_dataPollingTimerEventInProgress); // This seems to do the trick. But I it seems a little ugly.
    }

	if (_serialPortFileDescriptor)
    {
        close(_serialPortFileDescriptor);
        NSLog(@"Serial port closed");
    }
}

- (void) dataPollingEvent: (NSTimer *) theTimer
{
	static int timeoutCounter = 0;
    
	_dataPollingTimerEventInProgress = YES;
	
    int nbytes;
	if ((nbytes = read(_serialPortFileDescriptor, _telemetryDataBuffer, FRSKY_TELEM_BUFFER_SIZE)) > 0)
    {
        // parse all bytes so far received ...
		for(int i = 0; i < nbytes; i++)
			[self parseTelemetryByte:(unsigned char)_telemetryDataBuffer[i] ];
	}
    
	self.telemetryDataBufferUsage = nbytes;
    
	if (nbytes == 0)
    {
		timeoutCounter++;

		if ((timeoutCounter >= 1) && (timeoutCounter < 10))
			self.telemtryDataStreamStatus = DATA_STREAM_PAUSED;

		if (timeoutCounter >= 10)
        {
			timeoutCounter--; // prevent timeoutCounter from going higher
			self.telemtryDataStreamStatus = DATA_STREAM_STOPPED;
		}
	}
    else
    {
		timeoutCounter = 0;
		self.telemtryDataStreamStatus = DATA_STREAM_FLOWING;
	}
	
	_dataPollingTimerEventInProgress = NO;
}


/*
 * Each telemtry byte received is sent through this data parsing state machine.
 * Eventually, we expect to have built a complete Fr-Sky telemetry data packet,
 * which is this handed off (synchronously) to parseFrskyPacket:withByteCount:
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
 * Each complete Fr-Sky telemtry data packet is sent here for decoding and
 * storing of its contained data. In the case of a User Data packet (data sent
 * into the RC receiver's User Data port, at 9600 Baud) the data in said packet
 * may be sent off to parseTelemHubByte: for parsing (one byte at a time).
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
            struct FrskyAlarmData *alarmPtr;
            
            // set alarmptr to address of _frskyAlarmsStruct[n],
            // where n is derived from the packet type in packetBuffer[0]
            int alarmIndex = (packetBuffer[0]-TELEM_PKT_TYPE_A2B/*0xf9*/);
            alarmPtr = &_frskyAlarmsStruct[alarmIndex];
            alarmPtr->value = packetBuffer[1];
            alarmPtr->greater = packetBuffer[2] & 0x01;
            alarmPtr->level = packetBuffer[3] & 0x03;
            
            // Call delegate function to do something with the new alarm data
            if ([self.delegate respondsToSelector:@selector(frskyAlarmDataArrivedInCStruct:forAlarmIndex:)] )
            {
                [self.delegate frskyAlarmDataArrivedInCStruct: *alarmPtr forAlarmIndex:alarmIndex];
            }
        }
            break;
            
        case TELEM_PKT_TYPE_LINK: // A1/A2/RSSI[1/2] values
            _frskyLinkData.frskyA1Value = packetBuffer[1];
            _frskyLinkData.frskyA2Value = packetBuffer[2];
            _frskyLinkData.frskyRSSI1 = packetBuffer[3];
            _frskyLinkData.frskyRSSI2 = packetBuffer[4];

            if ([self.delegate respondsToSelector:@selector(frskyLinkDataArrivedInCStruct:)] )
            {
                [self.delegate frskyLinkDataArrivedInCStruct: _frskyLinkData];
            }
            break;
            

        case TELEM_PKT_TYPE_USER:   // User Data packet
        {
            int numBytes = 3 + (packetBuffer[1] & 0x07); // sanitize in case data corruption leads to buffer overflow
            
            // Ask delegate if we should be processing Fr-Sky Hub data or not, at the moment
            if ([self.delegate respondsToSelector:@selector(telemetryParserShouldProcessFrskyHubData)]
                && [self.delegate telemetryParserShouldProcessFrskyHubData])
            {
                for (int i=3; i < numBytes; i++)
                {
                    [self parseTelemHubByte: packetBuffer[i] ];
                }
            }
            else // there was no delegate method or the answer was NO
            {
                if ([self.delegate respondsToSelector:@selector(frskyUserDataArrivedInString:)])
                {
                    // Call delegate's frskyUserDataArrivedInString: (if it exists) to have something done with this new
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
 * This state machine parses a single byte of Fr-Sky telemetry User Data (from the receiver's 
 * User Data port, where the Fr-Sky Hub plugs into), from parseFrskyPacket:withByteCount:. When 
 * a complete Fr-Sky hub data packet is received, a delegate function is called, passwing the 
 * packet data for processing elsewhere.
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

/*
 * Sends a telemtry control packet (to the TX module) incuding byte stuffing (special character escaping)
 */
- (void) sendPacket: (unsigned char *)packetBuf withByteCount:(int)length
{
    // We can only send serial chars using pointers to buffers. So we need a couple buffered, const chars ...
    char bufBYTE_STUFF = TELEM_BYTE_STUFF;
    char bufSTART_STOP = TELEM_START_STOP;
    
	if (_serialPortFileDescriptor > 0) {
		write(_serialPortFileDescriptor, &bufSTART_STOP, 1);
		for (int i = 0; i < length; i++) {
            if ((packetBuf[i] == TELEM_START_STOP) || (packetBuf[i] == TELEM_BYTE_STUFF))
            {
                write(_serialPortFileDescriptor, &bufBYTE_STUFF, 1);    // send (insert) byte-stuff char before buffered char
                packetBuf[i] &= ~TELEM_STUFF_MASK;                      // convert 0x7e or 0x7d char to 0x5e or 0x5d
            }
            write(_serialPortFileDescriptor, &packetBuf[i], 1);         // send the buffered char
           
		}
		write(_serialPortFileDescriptor, &bufSTART_STOP, 1);
	}
}

#define ALARM_CONTROL_PACKET_SIZE 9
- (void) sendAlarmSetPacketWithHeaderByte:(unsigned char)headerByte usingAlarmDataCStruct:(struct FrskyAlarmData) alarmData
{
    unsigned char packet[ALARM_CONTROL_PACKET_SIZE];
    int i = 0;

    packet[i++] = headerByte;
	packet[i++] = alarmData.value;
	packet[i++] = alarmData.greater;
	packet[i++] = alarmData.level;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	packet[i++] = 0x00;
	
	[self sendPacket:packet withByteCount:ALARM_CONTROL_PACKET_SIZE];
}

- (void) requestAlarmSettings
{
    unsigned char packet[ALARM_CONTROL_PACKET_SIZE];
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
	
	[self sendPacket:packet withByteCount:ALARM_CONTROL_PACKET_SIZE];
}

@end
