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
// AUTHOR NOTES:
// This app was originally thrown together in a blur of trying to learn Xcode v3.2 and
// Objective-C for the first time, in 2010. It was later updated to use newer Xcode 4 conventions,
// like automatic property synthesis and ARC instead of garbage collection,  etc. Later still
// (2013) the learning curve extended to making the program fully comply with the MVC design
// pattern -- enabled for the most part by using protocols and delegates.
//                                                                                    -- Gruvin.


#import <Cocoa/Cocoa.h>
#import "Telemetry Parser.h"

// We are going to use pure C system calls for serial comms ...
#include <fcntl.h>      // File control definitions */
#include <termios.h>    // POSIX terminal control definitions (baud, flow, data format constants)
#include <libgen.h>     // for basename()

#include <IOKit/serial/IOSerialKeys.h>


#define DEBUG 0

@interface FrSky_Terminal : NSObject <NSApplicationDelegate, NSComboBoxDelegate, TelemtryParserDelegate>

@end
