//
//  FrSky_TerminalAppDelegate.h
//  FrSky Terminal
//
//  Created by Bryan on 28/11/10.
//  Copyright 2010 Bryan J. Rentoul. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FrSky_TerminalAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
