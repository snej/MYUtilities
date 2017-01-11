//
//  MYBackgroundMonitor.m
//  MYUtilities
//
//  Created by Jens Alfke on 9/24/15.
//  Copyright © 2015 Jens Alfke. All rights reserved.
//

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


- (instancetype) init {
    self = [super init];
    if (self) {
        _bgTask = UIBackgroundTaskInvalid;
    }
    return self;
}


- (void) start {
#if NS_EXTENSION_UNAVAILABLE_IOS
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
        if (UIApplication.sharedApplication.applicationState == UIApplicationStateBackground)
            [self appBackgrounding: nil];
    });
#endif
}


- (void) stop {
#if NS_EXTENSION_UNAVAILABLE_IOS
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [self endBackgroundTask];
#endif
}


- (void) dealloc {
    [self stop];
}


- (BOOL) endBackgroundTask {
#if NS_EXTENSION_UNAVAILABLE_IOS
    @synchronized(self) {
        if (_bgTask == UIBackgroundTaskInvalid)
            return NO;
        [[UIApplication sharedApplication] endBackgroundTask: _bgTask];
        _bgTask = UIBackgroundTaskInvalid;
        return YES;
    }
#else
    return NO;
#endif
}


- (BOOL) beginBackgroundTaskNamed: (NSString*)name {
#if NS_EXTENSION_UNAVAILABLE_IOS
    @synchronized(self) {
        if (_bgTask == UIBackgroundTaskInvalid) {
            _bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName: name
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
#else
    return NO;
#endif
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
