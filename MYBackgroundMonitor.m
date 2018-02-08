//
//  MYBackgroundMonitor.m
//  MYUtilities
//
//  Created by Jens Alfke on 9/24/15.
//  Copyright © 2015 Jens Alfke. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "MYBackgroundMonitor.h"
#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>


@implementation MYBackgroundMonitor
{
    NSString* _name;
    UIBackgroundTaskIdentifier _bgTask;
}


@synthesize onAppBackgrounding=_onAppBackgrounding, onAppForegrounding=_onAppForegrounding;
@synthesize onBackgroundTaskExpired=_onBackgroundTaskExpired;


static BOOL runningInAppExtension() {
    return [[[[NSBundle mainBundle] bundlePath] pathExtension] isEqualToString: @"appex"];
}


static UIApplication* sharedApplication() {
    return [[UIApplication class] performSelector: @selector(sharedApplication)];
}


- (instancetype) init {
    self = [super init];
    if (self) {
        _bgTask = UIBackgroundTaskInvalid;
    }
    return self;
}


- (void) start {
    if (runningInAppExtension())
        return;
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(appBackgrounding:)
                                                 name: UIApplicationDidEnterBackgroundNotification
                                               object: nil];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(appForegrounding:)
                                                 name: UIApplicationWillEnterForegroundNotification
                                               object: nil];
    // Already in the background? Better start a background session now:
    dispatch_async(dispatch_get_main_queue(), ^{
        if (sharedApplication().applicationState == UIApplicationStateBackground)
            [self appBackgrounding: nil];
    });
}


- (void) stop {
    if (runningInAppExtension())
        return;
    
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [self endBackgroundTask];
}


- (void) dealloc {
    [self stop];
}


- (BOOL) endBackgroundTask {
    if (runningInAppExtension())
        return NO;
    
    @synchronized(self) {
        if (_bgTask == UIBackgroundTaskInvalid)
            return NO;
        [sharedApplication() endBackgroundTask: _bgTask];
        _bgTask = UIBackgroundTaskInvalid;
        return YES;
    }
}


- (BOOL) beginBackgroundTaskNamed: (NSString*)name {
    if (runningInAppExtension())
        return NO;
    
    @synchronized(self) {
        if (_bgTask == UIBackgroundTaskInvalid) {
            _bgTask = [sharedApplication() beginBackgroundTaskWithName: name
                                                     expirationHandler: ^{
                // Process ran out of background time before endBackgroundTask was called.
                // NOTE: Called on the main thread
                if (_bgTask != UIBackgroundTaskInvalid) {
                    if (_onBackgroundTaskExpired)
                        _onBackgroundTaskExpired();
                    [self endBackgroundTask];
                }
            }];
        }
        return (_bgTask != UIBackgroundTaskInvalid);
    }
}


- (BOOL) hasBackgroundTask {
    @synchronized(self) {
        return _bgTask != UIBackgroundTaskInvalid;
    }
}


- (void) appBackgrounding: (NSNotification*)n {
    if (_onAppBackgrounding)
        _onAppBackgrounding();
}


- (void) appForegrounding: (NSNotification*)n {
    if (_onAppForegrounding)
        _onAppForegrounding();
}


@end

#endif // TARGET_OS_IPHONE
