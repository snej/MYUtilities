//
//  MYBlockUtils.m
//  MYUtilities
//
//  Created by Jens Alfke on 1/28/12.
//  Copyright (c) 2012 Jens Alfke. All rights reserved.
//

#import "MYBlockUtils.h"
#import "Test.h"


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
