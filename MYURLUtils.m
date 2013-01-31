//
//  MYURLUtils.m
//  MYUtilities
//
//  Created by Jens Alfke on 5/15/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "MYURLUtils.h"


@implementation NSURL (MYUtilities)


- (UInt16) my_effectivePort {
    NSNumber* portObj = self.port;
    if (portObj)
        return portObj.unsignedShortValue;
    return self.my_isHTTPS ? 443 : 80;
}


- (BOOL) my_isHTTPS {
    return (0 == [self.scheme caseInsensitiveCompare: @"https"]);
}


- (NSString*) my_pathAndQuery {
    CFStringRef path = CFURLCopyPath((CFURLRef)self);
    CFStringRef resource = CFURLCopyResourceSpecifier((CFURLRef)self);
    NSString* result = [(id)path stringByAppendingString: (id)resource];
    CFRelease(path);
    CFRelease(resource);
    return result;
}


- (NSURL*) my_URLByRemovingUser {
    CFRange userRange, userPlusDelimRange, passPlusDelimRange;
    userRange = CFURLGetByteRangeForComponent((CFURLRef)self, kCFURLComponentUser, &userPlusDelimRange);
    CFURLGetByteRangeForComponent((CFURLRef)self, kCFURLComponentPassword, &passPlusDelimRange);
    if (userRange.length == 0)
        return self;
    CFIndex delEnd;
    if (passPlusDelimRange.length == 0)
        delEnd = userPlusDelimRange.location + userPlusDelimRange.length;
    else
        delEnd = passPlusDelimRange.location+passPlusDelimRange.length;

    UInt8 urlBytes[1024];
    CFIndex nBytes = CFURLGetBytes((CFURLRef)self, urlBytes, sizeof(urlBytes) - 1);
    if (nBytes < 0)
        return self;
    memmove(urlBytes + userRange.location,
            urlBytes + delEnd,
            nBytes - delEnd);
    nBytes -= delEnd - userRange.location;
    CFURLRef newURL = CFURLCreateWithBytes(NULL, urlBytes, nBytes,
                                           kCFStringEncodingUTF8,  NULL);
    Assert(newURL != nil);
    return [(id)newURL autorelease];
}


- (NSURLProtectionSpace*) my_protectionSpaceWithRealm: (NSString*)realm
                                 authenticationMethod: (NSString*)authenticationMethod
{
    NSString* protocol = self.my_isHTTPS ? NSURLProtectionSpaceHTTPS
                                         : NSURLProtectionSpaceHTTP;
    return [[[NSURLProtectionSpace alloc] initWithHost: self.host
                                                  port: self.my_effectivePort
                                              protocol: protocol
                                                 realm: realm
                                  authenticationMethod: authenticationMethod]
            autorelease];
}


- (NSURLCredential*) my_credentialForRealm: (NSString*)realm
                      authenticationMethod: (NSString*)authenticationMethod
{
    if ($equal(authenticationMethod, NSURLAuthenticationMethodServerTrust))
        return nil;
    NSString* username = self.user;
    NSString* password = self.password;
    if (username && password)
        return [NSURLCredential credentialWithUser: username password: password
                                       persistence: NSURLCredentialPersistenceForSession];
    
    NSURLProtectionSpace* space = [self my_protectionSpaceWithRealm: realm
                                               authenticationMethod: authenticationMethod];
    NSURLCredentialStorage* storage = [NSURLCredentialStorage sharedCredentialStorage];
    if (username)
        return [[storage credentialsForProtectionSpace: space] objectForKey: username];
    else
        return [storage defaultCredentialForProtectionSpace: space];
}


@end


TestCase(MYURLUtils) {
    NSURL* url = $url(@"https://example.com/path/here?query#fragment");
    CAssertEqual(url.my_URLByRemovingUser, url);
    url = $url(@"https://bob@example.com/path/here?query#fragment");
    CAssertEqual(url.my_URLByRemovingUser, $url(@"https://example.com/path/here?query#fragment"));
    url = $url(@"https://bob:foo@example.com/path/here?query#fragment");
    CAssertEqual(url.my_URLByRemovingUser, $url(@"https://example.com/path/here?query#fragment"));
}
