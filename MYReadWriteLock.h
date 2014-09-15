//
//  MYReadWriteLock.h
//  CouchbaseLite
//
//  Created by Jens Alfke on 9/15/14.
//
//

#import <Foundation/Foundation.h>


/** A multi-reader/single-writer lock. Based on a pthread_rwlock. */
@interface MYReadWriteLock : NSObject <NSLocking>

@property (copy) NSString* name;

- (void) lock;
- (BOOL) tryLock;

- (void) lockForWriting;
- (BOOL) tryLockForWriting;

- (void) unlock;

- (void) withLock: (void(^)())block;
- (void) withWriteLock: (void(^)())block;

@end
