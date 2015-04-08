//
//  MYBuffer.m
//  BLIPSync
//
//  Created by Jens Alfke on 4/5/15.
//  Copyright (c) 2015 Couchbase. All rights reserved.
//

#import "MYBuffer.h"

#define kChunkCapacity 4096


@implementation MYBuffer
{
    NSMutableArray* _chunks;
    NSMutableData* _writingChunk;      // data chunk currently being written to

    size_t _chunkReadOffset;
}

- (instancetype) init {
    self = [super init];
    if (self) {
        _chunks = [NSMutableArray array];
    }
    return self;
}

- (instancetype) initWithData: (NSData*)data {
    self = [self init];
    if (self) {
        if (data)
            [self writeData: data];
    }
    return self;
}

- (void)dealloc {
    for (id source in _chunks) {
        if ([source isKindOfClass: [NSInputStream class]])
            [source close];
    }
}


- (BOOL) lengthKnown {
    for (id chunk in _chunks) {
        if (![chunk isKindOfClass: [NSData class]])
            return NO;
    }
    return YES;
}

- (NSUInteger) minLength {
    NSUInteger len = 0;
    for (id chunk in _chunks) {
        if ([chunk isKindOfClass: [NSData class]])
            len += [chunk length];
    }
    return len;
}

- (NSUInteger) maxLength {
    NSUInteger len = 0;
    for (id chunk in _chunks) {
        if ([chunk isKindOfClass: [NSData class]])
            len += [chunk length];
        else
            return NSIntegerMax;
    }
    return len;
}


#pragma mark - WRITING:


- (void) writeSlice: (MYSlice)slice {
    if (slice.length == 0)
        return;
    if (_writingChunk && _writingChunk.length + slice.length > kChunkCapacity)
        _writingChunk = nil;
    if (!_writingChunk) {
        _writingChunk = [NSMutableData dataWithCapacity: kChunkCapacity];
        [_chunks addObject: _writingChunk];
    }
    [_writingChunk appendBytes: slice.bytes length: slice.length];
}

- (void) writeData: (NSData*)data {
    NSUInteger length = data.length;
    if (length == 0) {
        return;
    } else if (_writingChunk.length + length <= kChunkCapacity) {
        [self writeSlice: MYMakeSlice(data.bytes, length)];
    } else {
        _writingChunk = nil;
        [_chunks addObject: [data copy]];
    }
}

- (void) writeContentsOfStream: (NSInputStream*)inputStream {
    _writingChunk = nil;
    [_chunks addObject: inputStream];
}


#pragma mark - READING:


- (ssize_t) readBytes: (void*)buffer maxLength: (size_t)maxLength {
    ssize_t bytesRead = 0;
    id chunk;
    while (maxLength > 0 && nil != (chunk = _chunks.firstObject)) {
        ssize_t nRead;
        if ([chunk isKindOfClass: [NSData class]]) {
            // Read from NSData:
            NSData* data = chunk;
            nRead = MIN(data.length - _chunkReadOffset, maxLength);
            memcpy(buffer, (uint8_t*)data.bytes + _chunkReadOffset, nRead);
            _chunkReadOffset += nRead;
            if (_chunkReadOffset >= data.length) {
                [_chunks removeObjectAtIndex: 0]; // remove data source when done
                _chunkReadOffset = 0;
            }
            bytesRead += nRead;
        } else {
            // Read from NSInputStream:
            NSInputStream* stream = chunk;
            nRead = [stream read: buffer maxLength: maxLength];
            if (nRead < 0) {
                return nRead; // read error!
            }
            if (nRead == 0 || stream.streamStatus == NSStreamStatusAtEnd) {
                [stream close]; // EOF
                [_chunks removeObjectAtIndex: 0];
            }
            if (nRead > 0) {
                bytesRead += nRead;
                break; // exit after successful read from stream
            }
        }
        buffer = (uint8_t*)buffer + nRead;
        maxLength -= nRead;
    }
    return bytesRead;
}

- (MYSlice) readSliceOfMaxLength: (size_t)maxLength {
    id chunk = _chunks.firstObject;
    if ([chunk isKindOfClass: [NSData class]]) {
        size_t bytesRead = MIN([chunk length] - _chunkReadOffset, maxLength);
        MYSlice result = MYMakeSlice((uint8_t*)[chunk bytes] + _chunkReadOffset, bytesRead);
        _chunkReadOffset += bytesRead;
        // Note: can't remove source from _sources even if it's used up, because that would
        // invalidate the returned pointer into the data. It will be removed on the next readBytes:
        return result;
    } else if ([chunk isKindOfClass: [NSInputStream class]]) {
        CFIndex length;
        const uint8_t* buffer = CFReadStreamGetBuffer((__bridge CFReadStreamRef)chunk,
                                                      maxLength, &length);
        if (buffer)
            return MYMakeSlice(buffer, length);
    }
    return MYNullSlice();
}


- (NSData*) flattened {
    id firstChunk = _chunks.firstObject;
    if (_chunkReadOffset == 0 && _chunks.count == 1 && [firstChunk isKindOfClass: [NSData class]])
        return firstChunk;  // already flat
    NSMutableData* flat = [NSMutableData dataWithCapacity: self.minLength];
    for (id chunk in _chunks) {
        if (![chunk isKindOfClass: [NSData class]])
            return nil;
        NSData* data = chunk;
        if (data == firstChunk)
            data = [data subdataWithRange: NSMakeRange(_chunkReadOffset,
                                                         data.length - _chunkReadOffset)];
        [flat appendData: data];
    }
    [_chunks removeAllObjects];
    [_chunks addObject: flat];
    _chunkReadOffset = 0;
    return flat;
}


- (BOOL) hasBytesAvailable {
    for (id chunk in _chunks) {
        if ([chunk isKindOfClass: [NSData class]]) {
            if (_chunkReadOffset < [chunk length])
                return YES;
        } else {
            NSInputStream* stream = chunk;
            if (stream.streamStatus < NSStreamStatusAtEnd)
                return stream.hasBytesAvailable;
        }
    }
    return NO;
}

- (BOOL) atEnd {
    for (id chunk in _chunks) {
        if ([chunk isKindOfClass: [NSData class]]) {
            if (_chunkReadOffset < [chunk length])
                return NO;
        } else {
            if (((NSInputStream*)chunk).streamStatus < NSStreamStatusAtEnd)
                return NO;
        }
    }
    return YES;
}



@end
