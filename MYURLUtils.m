//
//  MYURLUtils.m
//  MYUtilities
//
//  Created by Jens Alfke on 5/15/12.
//  Copyright (c) 2012 Jens Alfke. All rights reserved.
//

#import "MYURLUtils.h"
#import "Test.h"


@implementation NSURL (MYUtilities)


- (UInt16) my_effectivePort {
    TestedBy(MYURLUtils);
    NSNumber* portObj = self.port;
    if (Cover(portObj))
        return portObj.unsignedShortValue;
    return self.my_isHTTPS ? 443 : 80;
}


- (BOOL) my_isHTTPS {
    return (0 == [self.scheme caseInsensitiveCompare: @"https"]);
}


- (NSURL*) my_baseURL {
    TestedBy(MYURLUtils);
    NSString* scheme = self.scheme.lowercaseString;
    NSMutableString* str = [NSMutableString stringWithFormat: @"%@://%@",
                            scheme, self.host.lowercaseString];
    NSNumber* port = self.port;
    if (Cover(port)) {
        int defaultPort = [scheme isEqualToString: @"https"] ? 443 : 80;
        if (Cover(port.intValue != defaultPort))
            [str appendFormat: @":%@", port];
    }
    return [NSURL URLWithString: str];
}


- (NSString*) my_pathAndQuery {
    CFStringRef path = CFURLCopyPath((CFURLRef)self);
    CFStringRef resource = CFURLCopyResourceSpecifier((CFURLRef)self);
    NSString* result = [(__bridge id)path stringByAppendingString: (__bridge id)resource];
    CFRelease(path);
    CFRelease(resource);
    return result;
}


- (NSURL*) my_URLByRemovingUser {
    TestedBy(MYURLUtils);
    CFRange userRange, userPlusDelimRange, passPlusDelimRange;
    userRange = CFURLGetByteRangeForComponent((CFURLRef)self, kCFURLComponentUser, &userPlusDelimRange);
    CFURLGetByteRangeForComponent((CFURLRef)self, kCFURLComponentPassword, &passPlusDelimRange);
    if (Cover(userRange.length == 0))
        return self;
    CFIndex delEnd;
    if (Cover(passPlusDelimRange.length == 0))
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
    Assert(newURL != NULL);
    return CFBridgingRelease(newURL);
}


- (NSURLProtectionSpace*) my_protectionSpaceWithRealm: (NSString*)realm
                                 authenticationMethod: (NSString*)authenticationMethod
{
    NSString* protocol = self.my_isHTTPS ? NSURLProtectionSpaceHTTPS
                                         : NSURLProtectionSpaceHTTP;
    return [[NSURLProtectionSpace alloc] initWithHost: self.host
                                                 port: self.my_effectivePort
                                             protocol: protocol
                                                realm: realm
                                 authenticationMethod: authenticationMethod];
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
                                       persistence: NSURLCredentialPersistenceNone];
    
    NSURLProtectionSpace* space = [self my_protectionSpaceWithRealm: realm
                                               authenticationMethod: authenticationMethod];
    NSURLCredentialStorage* storage = [NSURLCredentialStorage sharedCredentialStorage];
    if (username)
        return [[storage credentialsForProtectionSpace: space] objectForKey: username];
    else
        return [storage defaultCredentialForProtectionSpace: space];
}


- (NSDictionary*) my_proxySettings {
    CFDictionaryRef proxySettings = CFNetworkCopySystemProxySettings();
    if (!proxySettings)
        return nil;
    NSArray* proxies = CFBridgingRelease(CFNetworkCopyProxiesForURL((__bridge CFURLRef)self,
                                                                    proxySettings));
    CFRelease(proxySettings);
    if (proxies.count == 0)
        return nil;
    NSDictionary* proxy = proxies[0];
    if ($equal(proxy[(id)kCFProxyTypeKey], (id)kCFProxyTypeNone))
        return nil;
    return proxy;
}


- (NSString*) my_sanitizedString {
    TestedBy(MYURLUtils);
    CFRange passRange = CFURLGetByteRangeForComponent((CFURLRef)self, kCFURLComponentPassword, NULL);
    if (Cover(passRange.length == 0))
        return self.absoluteString;
    NSUInteger passEnd = passRange.location + passRange.length;

    CFIndex nBytes = CFURLGetBytes((CFURLRef)self, NULL, 0);
    UInt8 urlBytes[nBytes];
    CFURLGetBytes((CFURLRef)self, urlBytes, sizeof(urlBytes));
    
    NSString* before = [[NSString alloc] initWithBytes: urlBytes
                                                length: passRange.location
                                              encoding:NSUTF8StringEncoding];
    NSString* after = [[NSString alloc] initWithBytes: &urlBytes[passEnd]
                                               length: (nBytes - passEnd)
                                             encoding:NSUTF8StringEncoding];
    return [NSString stringWithFormat: @"%@*****%@", before, after];
}


@end


TestCase(MYURLUtils) {
    NSURL* url = $url(@"https://example.com/path/here?query#fragment");
    CAssertEq(url.my_effectivePort, 443);
    CAssertEqual(url.my_baseURL, $url(@"https://example.com"));
    CAssertEqual(url.my_URLByRemovingUser, url);
    CAssertEqual(url.my_sanitizedString, @"https://example.com/path/here?query#fragment");

    url = $url(@"https://example.com:8080/path/here?query#fragment");
    CAssertEq(url.my_effectivePort, 8080);
    CAssertEqual(url.my_baseURL, $url(@"https://example.com:8080"));
    CAssertEqual(url.my_URLByRemovingUser, url);
    CAssertEqual(url.my_sanitizedString, @"https://example.com:8080/path/here?query#fragment");

    CAssertEqual($url(@"http://example.com:80/path/here?query#fragment").my_baseURL,
                 $url(@"http://example.com"));
    CAssertEq($url(@"http://example.com:80/path/here?query#fragment").my_effectivePort, 80);
    CAssertEqual($url(@"https://example.com:443/path/here?query#fragment").my_baseURL,
                 $url(@"https://example.com"));

    url = $url(@"https://bob@example.com/path/here?query#fragment");
    CAssertEqual(url.my_URLByRemovingUser, $url(@"https://example.com/path/here?query#fragment"));
    CAssertEqual(url.my_sanitizedString, @"https://bob@example.com/path/here?query#fragment");

    url = $url(@"https://bob:foo@example.com/path/here?query#fragment");
    CAssertEqual(url.my_URLByRemovingUser, $url(@"https://example.com/path/here?query#fragment"));
    CAssertEqual(url.my_sanitizedString, @"https://bob:*****@example.com/path/here?query#fragment");
}



/*
 Copyright (c) 2008-2013, Jens Alfke <jens@mooseyard.com>. All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted
 provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions
 and the following disclaimer in the documentation and/or other materials provided with the
 distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRI-
 BUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
 THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
