//
//  MYBackgroundMonitor.h
//  MYUtilities
//
//  Created by Jens Alfke on 9/24/15.
//  Copyright © 2015 Jens Alfke. All rights reserved.
//

#import <Foundation/Foundation.h>


/** Monitors when a UIKit app enters/leaves the background, and allows the client to start a
    "background task" to request more time to finish an activity. */
@interface MYBackgroundMonitor : NSObject

/** Starts the monitor. */
- (void) start;

/** Explicitly stops the monitor. (So does deallocing it.) */
- (void) stop;

/** Starts a background task. Should be called from the onAppBackgrounding block.
    Does nothing if the background task is already active.
    Returns YES on success, NO if running in the background is not possible.
    NOTE: Should be called on the main thread. */
- (BOOL) beginBackgroundTaskNamed: (NSString*)name;

/** Tells the OS that the current background task is done.
    NOTE: Should be called on the main thread.
    @return  YES if there was a background task, NO if none was running. */
- (BOOL) endBackgroundTask;

/** YES if there is currently a background task. */
@property (atomic, readonly) BOOL hasBackgroundTask;

/** This block will be called when the app goes into the background.
    The app will soon stop being scheduled for CPU time unless the block starts a background task
    by calling -beginBackgroundTaskNamed:. 
    NOTE: Called on the main thread. */
@property (atomic, strong) void (^onAppBackgrounding)();

/** Called when the app returns to the foreground.
    NOTE: Called on the main thread. */
@property (atomic, strong) void (^onAppForegrounding)();

/** Called if the OS loses its patience before -endBackgroundTask is called.
    The task is implicitly ended, and the app will soon stop being scheduled for CPU time.
    NOTE: Called on the main thread. */
@property (atomic, strong) void (^onBackgroundTaskExpired)();

@end
