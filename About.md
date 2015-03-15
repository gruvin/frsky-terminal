# About Fr-Sky Terminal #

Owners of [Fr-Sky "2.4GHz Two Way Communication System](http://www.frsky-rc.com/Products.asp?BigClassID=17) modules will have received a CD containing a basic Windows program named, 'fdd lite'. This program allows the user to see a representation of telemetry data as sent to the local transmitter from the remote receiver module. (No, I didn't confuse transmitter and receiver in that sentence! :-P)

The purpose of this program is to provide similar (and potentially more useful) functions to 'fdd lite' in a native Mac OS X application.

# Screen Shot #

![http://frsky-terminal.googlecode.com/svn/wiki/About.attach/screenshot.png](http://frsky-terminal.googlecode.com/svn/wiki/About.attach/screenshot.png)

# Download #

Please see the [FrSky Terminal project download area](http://code.google.com/p/frsky-terminal/downloads)

NOTE: This application is the author's first such production under Apple's Xcode. I have tried to ensure that it will run on Mac OS X down to about version 10.3 and also n Intel or PPC machines. Unfortunately I have no way to actually test such compatibility, other than user feedback. Please let me know if you encounter any issues.

# Usage #

The program displays values from three analogue sources at the RC receiver - A1, A2 and RSSI (Received Signal Strength Indicator). RSSI is also translated and presented as a horrizontal signal strength bar for easy visual recognition.

The large white text box display serial "User Data" that is send into the remote receiver's 'RX' port at 9600 baud. (Yes, the names 'RX, TX, transmitter and receiver get a little confusing in this context!)

> _Note that although the remote baud rate is 9600 baud, the actual continuous data rate cannot exceed about 1200 bytes per second for more than about 255 characters over the long term. That is, you can send up to about 255 characters at 9600 baud. But there then has to be a delay for the buffer to clear before sending another burst. This is because the output baud rate at the local transmitter end is also 9600 baud, and there's considerable overhead in multiplexing A1/A2/RSSI data with user data. The internal RF-layer data rate allowing, it would be nice if Fr-Sky could make the local serial data output run at 38,400 baud to allow constant 9600 baud user data through the system. Note also that the Fr-Sky modules take care of RF-later error correction -- so the data received is always the data sent, without errors, which is very nice indeed. This feature can also incur some RF-layer data rate overhead of course._

The text area can display incoming data as plain ASCII text (as shown in the screen shot above) or as hexadecimal (HEX) or binary coded decimal (BCD) values. In BCD mode, the lowest significant digit comes first. So hex 0x41 (or 'A') will be displayed as  '14'. (A byte not encoded as BCD, such as '0xDC' will display weird characters. This is probably a design bug of this application and should be addressed in some way.)

Below the text box is the alarm functions interface. This is where you can set alarm thresholds, greater-than or less-than and 'tonal urgency' for the two analogue inputs A1 and A2. The alarms sound referred to here are those emitted from the Fr-Sky transmitter module itself.

Each channel can have up to two active alarms. The Ch1 alarms have a sort of 'warble' sound, while the Ch2 alarm sounds a clean tone. The 'tonal urgency' settings are named 'Yellow', 'Orange' and 'Red' in accordance with Fr-Sky documentation. In practice, these are sounded out as something like,

> 'Beep ............ Beep ............ Beep' for 'Yellow'

> 'Beep ...... Beep ...... Beep' for 'Orange' and

> 'Beep Beep Beep' for 'Red'.

The alarms area of FrSky Terminal also reports the current, recorded alarm settings for the connected transmitter module. The program sends a request for the alarm setting at start up and whenever a new data stream appears having been previously lost. However, if you need to, you can re-load the current settings by clicking the "Get Current" button.

# Future Plans #

## Actual Voltage Calculation ##
A common usage for the A1/A2 remote analogue ports is for sending back receiver or pther battery voltages. This usually requires a voltage divider be installed between the battery being measures and the A1/A2 port. The A1/A2 value range from 0 to 255, being 0 volts to 3.3V respectively. Fr-Sky supply divider modules, including a 6.6V maximum version. In this example, the values 0 to 255 become 0 to 6.6V. So the plan is to provide a 'max volts' entry box in FrSky Terminal so that an actual voltage can then be calculated and displayed.

## Other Ideas ##
At some point, I may add a feature to record data sample at regular interval and save them to a file.

Another idea is to provide some form of GPS data translation or logging and perhaps even on screen maps using Google Maps somehow. However, this type of thing is really beyond the design scope for this app and thus, if done at all, would more likely be done in a separate application altogether.

How about an iPhone app? Well, sure. If and when I ever get myself an iPhone ($$$!), I'd love to port an app like this to that platform. Serial to Bluetooth converters exist for under $50 and would be just the thing to get the data into an iPhone app.

## Add Stuff Yourself! ##
Of course, if you know how or are keen to learn how to program in Apple's Xcode, then you're more than welcome to use this program as a starting platform and do whatever yo want with it. The terms of the license encourage you to share whatever you might do back to the open source community -- and we eagerly look forward to any such input. :-D

# Contacting Gruvin #

Oh dear -- as of this writing, the Google Code system for obtaining owner email addresses is broken. Hopefully, Google will fix this very soon. Normally, you would visit my Google Projects [user profile](http://code.google.com/u/gruvin/), then click the '...' in gru...@gmail.com to reveal the full address. On the other hand, if you're very clever, you might just be able to work that out for yourself. Hint: My user alias is `gruvin`, not `gru...` ;-)