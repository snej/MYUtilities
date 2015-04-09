//
//  MYBlockUtils.m
//  MYUtilities
//
//  Created by Jens Alfke on 1/28/12.
//  Copyright (c) 2012 Jens Alfke. All rights reserved.
//

#import "MYBlockUtils.h"
#import "Test.h"
#import <libkern/OSAtomic.h>


@interface NSObject (MYBlockUtils)
- (void) my_run_as_block;
@end


/* This is sort of a kludge. This method only needs to be defined for blocks, but their class (NSBlock) isn't public, and the only public base class is NSObject. */
@implementation NSObject (MYBlockUtils)

- (void) my_run_as_block {
    ((void (^)())self)();
}

@end


void MYAfterDelay( NSTimeInterval delay, void (^block)() ) {
    block = [[block copy] autorelease];
    [block performSelector: @selector(my_run_as_block)
                withObject: nil
                afterDelay: delay];
}

id MYAfterDelayInModes( NSTimeInterval delay, NSArray* modes, void (^block)() ) {
    block = [[block copy] autorelease];
    [block performSelector: @selector(my_run_as_block)
                withObject: nil
                afterDelay: delay
                   inModes: modes];
    return block;
}

void MYCancelAfterDelay( id block ) {
    [NSObject cancelPreviousPerformRequestsWithTarget: block
                                             selector: @selector(my_run_as_block)
                                               object:nil];
}


static void MYOnThreadWaiting( NSThread* thread, BOOL waitUntilDone, void (^block)()) {
    block = [block copy];
    [block performSelector: @selector(my_run_as_block)
                  onThread: thread
                withObject: block
             waitUntilDone: waitUntilDone];
    [block release];
}


void MYOnThread( NSThread* thread, void (^block)()) {
    MYOnThreadWaiting(thread, NO, block);
}

void MYOnThreadSynchronously( NSThread* thread, void (^block)()) {
    MYOnThreadWaiting(thread, YES, block);
}


void MYOnThreadInModes( NSThread* thread, NSArray* modes, BOOL waitUntilDone, void (^block)()) {
    block = [block copy];
    [block performSelector: @selector(my_run_as_block)
                  onThread: thread
                withObject: block
             waitUntilDone: waitUntilDone
                     modes: modes];
    [block release];
}


BOOL MYWaitFor( NSString* mode, BOOL (^block)() ) {
    if (block())
        return YES;

    // Add a temporary input source for the private runloop mode, because -runMode:beforeDate: will
    // fail if there are no sources:
    NSPort* port = [NSPort port];
    [[NSRunLoop currentRunLoop] addPort: port forMode: mode];
    BOOL success = YES;
    do {
        if (![[NSRunLoop currentRunLoop] runMode: mode
                                      beforeDate: [NSDate distantFuture]]) {
            Warn(@"CBLDatabase waitFor: Runloop stopped");
            success = NO;
            break;
        }
    } while (!block());
    [[NSRunLoop currentRunLoop] removePort: port forMode: mode];
    return success;
}


dispatch_block_t MYThrottledBlock(NSTimeInterval minInterval, dispatch_block_t block) {
    __block CFAbsoluteTime lastTime = 0;
    block = [block copy];
    dispatch_block_t throttled = ^{
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        if (now - lastTime >= minInterval)
            block();
        lastTime = now;
    };
    return [throttled copy];
}


dispatch_block_t MYBatchedBlock(NSTimeInterval minInterval,
                                dispatch_queue_t queue,
                                void (^block)())
{
    __block uint8_t scheduled = 0;
    block = [block copy];
    dispatch_block_t batched = ^{
        uint8_t wasScheduled = OSAtomicTestAndSetBarrier(0, &scheduled);
        if (!wasScheduled) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(minInterval * NSEC_PER_SEC)),
                           queue, ^{
                OSAtomicTestAndClearBarrier(0, &scheduled);
                block();
            });
        }
    };
    return [batched copy];
}

TestCase(MYAfterDelay) {
    __block BOOL fired = NO;
    MYAfterDelayInModes(0.5, $array(NSRunLoopCommonModes), ^{fired = YES; NSLog(@"Fired!");});
    CAssert(!fired);
    
    while (!fired) {
        if (![[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                                      beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.5]])
            break;
    }
    CAssert(fired);
}
