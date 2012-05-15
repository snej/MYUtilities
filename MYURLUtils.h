//
//  MYURLUtils.h
//  TouchDB
//
//  Created by Jens Alfke on 5/15/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


static inline NSURL* $url(NSString* str) {
    return [NSURL URLWithString: str];
}


@interface NSURL (MYUtilities)

@property (readonly) UInt16 my_effectivePort;
@property (readonly) BOOL my_isHTTPS;

- (NSURLProtectionSpace*) my_protectionSpaceWithRealm: (NSString*)realm
                                 authenticationMethod: (NSString*)authenticationMethod;

- (NSURLCredential*) my_credentialForRealm: (NSString*)realm
                      authenticationMethod: (NSString*)authenticationMethod;

@end
