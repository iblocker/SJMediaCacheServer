//
//  MCSResourceReader.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResourceReader.h"
#import "MCSResource+MCSPrivate.h"
#import "MCSResourcePartialContent.h"
#import "MCSResourceResponse.h"
#import "MCSResourceFileManager.h"
#import "MCSResourceFileDataReader.h"
#import "MCSResourceNetworkDataReader.h"
#import "MCSUtils.h"

@interface MCSResourceReader ()<NSLocking, MCSResourceDataReaderDelegate> {
    NSRecursiveLock *_lock;
}

@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isPrepared;
@property (nonatomic) BOOL isClosed;

@property (nonatomic) NSInteger currentIndex;
@property (nonatomic, strong, nullable) id<MCSResourceDataReader> currentReader;
@property (nonatomic, strong, nullable) MCSResourceNetworkDataReader *tmpReader; // 用于获取资源contentLength, contentType等信息
@property (nonatomic) NSUInteger offset;

@property (nonatomic, weak, nullable) MCSResource *resource;
@property (nonatomic, strong) MCSDataRequest *request;
@property (nonatomic, copy, nullable) NSArray<id<MCSResourceDataReader>> *readers;
@property (nonatomic, strong, nullable) id<MCSResourceResponse> response;

@property (nonatomic, strong) NSMutableArray<MCSResourcePartialContent *> *referencedContents;
@end

@implementation MCSResourceReader

- (instancetype)initWithResource:(__weak MCSResource *)resource request:(MCSDataRequest *)request {
    self = [super init];
    if ( self ) {
        _referencedContents = NSMutableArray.array;
        _lock = NSRecursiveLock.alloc.init;
        _currentIndex = NSNotFound;

        _resource = resource;
        _request = request;
    }
    return self;
}

- (void)dealloc {
#ifdef DEBUG
    printf("%s: <%p>.dealloc;\n", NSStringFromClass(self.class).UTF8String, self);
#endif
}

- (void)prepare {
    [self lock];
    @try {
        if ( _isClosed || _isCalledPrepare )
            return;
         
#ifdef DEBUG
        printf("%s: <%p>.prepare { range: %s };\n", NSStringFromClass(self.class).UTF8String, self, NSStringFromRange(_request.range).UTF8String);
#endif
        
        _isCalledPrepare = YES;
        
        if ( _resource.totalLength == 0 || _resource.contentType.length == 0 ) {
            _tmpReader = [MCSResourceNetworkDataReader.alloc initWithURL:_request.URL requestHeaders:_request.headers range:NSMakeRange(0, 2)];
            _tmpReader.delegate = self;
#ifdef DEBUG
            printf("%s: <%p>.createTmpReader: <%p>;\n", NSStringFromClass(self.class).UTF8String, self, _tmpReader);
#endif
            [_tmpReader prepare];
        }
        else {
            [self _prepare];
        }
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    [self lock];
    @try {
        if ( _isClosed || _currentIndex == NSNotFound )
            return nil;
        
        NSData *data = [self.currentReader readDataOfLength:length];
        _offset += data.length;
        if ( self.currentReader.isDone )
            self.currentReader != self.readers.lastObject ? [self _prepareNextReader] : [self _close];
        return data;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (id<MCSResourceResponse>)response {
    [self lock];
    @try {
        return _response;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}
 
- (NSUInteger)offset {
    [self lock];
    @try {
        return _offset + _request.range.location;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (BOOL)isPrepared {
    [self lock];
    @try {
        return _isPrepared;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (BOOL)isReadingEndOfData {
    [self lock];
    @try {
        return _readers.lastObject.isDone;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)close {
    [self lock];
    @try {
        [self _close];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)_close {
    if ( _isClosed )
        return;
    
    _isClosed = YES;
    for ( id<MCSResourceDataReader> reader in _readers ) {
        [reader close];
    }
    
    for ( MCSResourcePartialContent *content in _referencedContents ) {
        [content reference_release];
    }
            
#ifdef DEBUG
    printf("%s: <%p>.close { range: %s };\n", NSStringFromClass(self.class).UTF8String, self, NSStringFromRange(_request.range).UTF8String);
#endif
}

#pragma mark -

- (void)_prepare {
    NSUInteger totalLength = _resource.totalLength;
    NSAssert(totalLength != 0, @"`_resource.totalLength`不能为`0`!");
     
    // `length`经常变动, 暂时这里排序吧
    __auto_type contents = [_resource.contents sortedArrayUsingComparator:^NSComparisonResult(MCSResourcePartialContent *obj1, MCSResourcePartialContent *obj2) {
        if ( obj1.offset == obj2.offset )
            return obj1.length >= obj2.length ? NSOrderedAscending : NSOrderedDescending;
        return obj1.offset < obj2.offset ? NSOrderedAscending : NSOrderedDescending;
    }];
    
    NSRange current = _request.range;
    // bytes=-500
    if      ( current.location == NSNotFound && current.length != NSNotFound )
        current.location = totalLength - current.length;
    // bytes=9500-
    else if ( current.location != NSNotFound && current.length == NSNotFound ) {
        current.length = totalLength - current.location;
    }
    else if ( current.location == NSNotFound && current.length == NSNotFound ) {
        current.location = 0;
        current.length = totalLength;
    }
    
    _response = [MCSResourceResponse.alloc initWithServer:_resource.server contentType:_resource.contentType totalLength:totalLength contentRange:current];

    NSMutableArray<id<MCSResourceDataReader>> *readers = NSMutableArray.array;
    for ( MCSResourcePartialContent *content in contents ) {
        NSRange available = NSMakeRange(content.offset, content.length);
        NSRange intersection = NSIntersectionRange(current, available);
        if ( intersection.length != 0 ) {
            // undownloaded part
            NSRange leftRange = NSMakeRange(current.location, intersection.location - current.location);
            if ( leftRange.length != 0 ) {
                MCSResourceNetworkDataReader *reader = [MCSResourceNetworkDataReader.alloc initWithURL:_request.URL requestHeaders:_request.headers range:leftRange];
                reader.delegate = self;
                [readers addObject:reader];
            }
            
            // downloaded part
            NSRange matchedRange = NSMakeRange(NSMaxRange(leftRange), intersection.length);
            NSRange fileRange = NSMakeRange(matchedRange.location - content.offset, intersection.length);
            NSString *path = [MCSResourceFileManager getContentFilePathWithName:content.name inResource:_resource.name];
            MCSResourceFileDataReader *reader = [MCSResourceFileDataReader.alloc initWithRange:matchedRange path:path readRange:fileRange];
            reader.delegate = self;
            [readers addObject:reader];
            
            // retain
            [content reference_retain];
            [_referencedContents addObject:content];
            
            // next part
            current = NSMakeRange(NSMaxRange(intersection), NSMaxRange(_request.range) - NSMaxRange(intersection));
        }
        
        if ( current.length == 0 || available.location > NSMaxRange(current) ) break;
    }
    
    if ( current.length != 0 ) {
        // undownloaded part
        MCSResourceNetworkDataReader *reader = [MCSResourceNetworkDataReader.alloc initWithURL:_request.URL requestHeaders:_request.headers range:current];
        reader.delegate = self;
        [readers addObject:reader];
    }
    
    _readers = readers.copy;
    
#ifdef DEBUG
    printf("%s: <%p>.createSubreaders { range: %s, count: %lu };\n", NSStringFromClass(self.class).UTF8String, self, NSStringFromRange(_request.range).UTF8String, _readers.count);
#endif

    [self _prepareNextReader];
}

- (void)_prepareNextReader {
    [self.currentReader close];

    if ( self.currentReader == _readers.lastObject )
        return;
    
    if ( _currentIndex == NSNotFound )
        _currentIndex = 0;
    else
        _currentIndex += 1;
    [self.currentReader prepare];
}

- (nullable id<MCSResourceDataReader>)currentReader {
    if ( _currentIndex != NSNotFound && _currentIndex < _readers.count ) {
        return _readers[_currentIndex];
    }
    return nil;
}

- (void)lock {
    [_lock lock];
}

- (void)unlock {
    [_lock unlock];
}

- (void)readerPrepareDidFinish:(id<MCSResourceDataReader>)reader {
    if ( self.isPrepared )
        return;
    
    [self lock];
    @try {
        if      ( _response != nil ) {
            _isPrepared = YES;
        }
        else if ( reader == _tmpReader ) {
            // update contentType & totalLength & server for `resource`
            [_resource setServer:MCSGetResponseServer(_tmpReader.response) contentType:MCSGetResponseContentType(_tmpReader.response) totalLength:MCSGetResponseContentRange(_tmpReader.response).totalLength];

            // clean
            [_tmpReader close];
            _tmpReader = nil;
            
            // prepare
            [self _prepare];
        }

        [self.delegate readerPrepareDidFinish:self];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)readerHasAvailableData:(id<MCSResourceDataReader>)reader {
    [_delegate readerHasAvailableData:self];
}

- (void)reader:(id<MCSResourceDataReader>)reader anErrorOccurred:(NSError *)error {
    [_delegate reader:self anErrorOccurred:error];
}

- (MCSResourcePartialContent *)newPartialContentForReader:(MCSResourceNetworkDataReader *)reader {
    [self lock];
    @try {
        MCSResourcePartialContent *content = [_resource createContentWithOffset:reader.range.location];
        [content reference_retain];
        [_referencedContents addObject:content];
        return content;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (NSString *)savePathOfPartialContent:(MCSResourcePartialContent *)content {
    return [_resource filePathOfContent:content];
}

@end