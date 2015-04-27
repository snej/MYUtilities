//
//  MYBuffer+Zip.m
//  MYUtilities
//
//  Created by Jens Alfke on 4/26/15.
//  Copyright (c) 2015 Jens Alfke. All rights reserved.
//

#import "MYBuffer+Zip.h"
#import "MYZip.h"
#import "Test.h"


#define kZippedBufferSize (8*1024)
#define kReadBufSize (16*1024)


static inline size_t move(MYSlice* dst, MYSlice* src, BOOL slideSrc) {
    size_t n = MIN(dst->length, src->length);
    if (n > 0) {
        memmove((void*)dst->bytes, src->bytes, n);
        dst->length -= n;
        dst->bytes += n;
        src->length -= n;
        if (slideSrc)
            memcpy((void*)src->bytes, src->bytes + n, src->length);
        else
            src->bytes += n;
    }
    return n;
}


@implementation MYZipReader
{
    id<MYReader> _reader;
    MYZip* _zipper;
    NSMutableData* _zippedBuf;
    MYSlice _zipped;
}

- (instancetype) initWithReader: (id<MYReader>)reader compressing: (BOOL)compressing {
    self = [super init];
    if (self) {
        _reader = reader;
        _zipper = [[MYZip alloc] initForCompressing: compressing];
        _zippedBuf = [[NSMutableData alloc] initWithLength: kZippedBufferSize];
        _zipped = (MYSlice){_zippedBuf.mutableBytes, 0};
    }
    return self;
}

- (void) appendToBuf: (MYSlice)new {
    if (_zipped.length + new.length > _zippedBuf.length) {
        _zippedBuf.length = _zipped.length + new.length;
        _zipped.bytes = _zippedBuf.mutableBytes;
    }
    memcpy((void*)_zipped.bytes+_zipped.length, &new.bytes, new.length);
    _zipped.length += new.length;

}

- (ssize_t) readBytes: (void*)dst maxLength: (size_t)maxLength {
    // First return already-zipped bytes from the _zipped buffer:
    __block MYSlice remaining = {dst, maxLength};
    __block ssize_t total = move(&remaining, &_zipped, YES);

    while (remaining.length > 0 && _reader != nil) {
        uint8_t readBuf[kReadBufSize];
        ssize_t n = [_reader readBytes: readBuf maxLength: sizeof(readBuf)];
        if (n <= 0) {
            _reader = nil;
            if (n < 0)
                return n; // error from _reader
        }
        __weak MYZipReader* weakSelf = self;
        [_zipper addBytes: readBuf length: n onOutput: ^(const void *zBytes, size_t zLen) {
            MYSlice new = {zBytes, zLen};
            total += move(&remaining, &new, NO);
            [weakSelf appendToBuf: new];
        }];
    }
    return total;
}

- (MYSlice) readSliceOfMaxLength: (size_t)maxLength {
    return (MYSlice){NULL, 0};
}

- (BOOL) hasBytesAvailable {
    return _zipped.length > 0 || _reader.hasBytesAvailable;
}

- (BOOL) atEnd {
    return _zipped.length == 0 && (!_reader ||  _reader.atEnd);
}

@end




@implementation MYZipWriter
{
    id<MYWriter> _writer;
    MYZip* _zipper;
    NSMutableData* _zippedBuf;
    MYSlice _zipped;
}

- (instancetype) initWithWriter: (id<MYWriter>)writer compressing: (BOOL)compressing {
    self = [super init];
    if (self) {
        _writer = writer;
        _zipper = [[MYZip alloc] initForCompressing: compressing];
    }
    return self;
}

- (BOOL) writeSlice: (MYSlice)slice {
    id<MYWriter> writer = _writer;
    return [_zipper addBytes: slice.bytes length: slice.length
                    onOutput: ^(const void *zBytes, size_t zLen) {
        [writer writeSlice: (MYSlice){zBytes, zLen}];
    }];
}

- (BOOL) writeData:(NSData *)data {
    return [self writeSlice: (MYSlice){data.bytes, data.length}];
}

- (BOOL) writeContentsOfStream: (NSInputStream*)inputStream {
    Assert(NO, @"UNIMPLEMENTED"); //TODO
}

@end
