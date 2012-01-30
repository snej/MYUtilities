//
//  MYBlockUtils.h
//  MYUtilities
//
//  Created by Jens Alfke on 1/28/12.
//  Copyright (c) 2012 Jens Alfke. All rights reserved.
//

#import <Foundation/Foundation.h>


/** Block-based equivalent to -performSelector:withObject:afterDelay:.
    @return A detached copy of the block; you can cancel the operation by passing this to MYCancelAfterDelay(). */
id MYAfterDelay( NSTimeInterval delay, void (^block)() );

/** Block-based equivalent to -performSelector:withObject:afterDelay:inModes:. */
id MYAfterDelayInModes( NSTimeInterval delay, NSArray* modes, void (^block)() );

/** Cancels a prior call to MYAfterDelay or MYAfterDelayInModes, before the delayed block runs.
    @param block  The return value of the MYAfterDelay call that you want to cancel. */
void MYCancelAfterDelay( id block );
