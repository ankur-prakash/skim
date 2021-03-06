//
//  NSData_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 9/8/07.
/*
 This software is Copyright (c) 2007-2010
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// For base 64 encoding/decoding:
//
//  Created by Matt Gallagher on 2009/06/03.
//  Copyright 2009 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import "NSData_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "SKRuntime.h"
#import <CommonCrypto/CommonDigest.h>


@implementation NSData (SKExtensions)

- (NSRange)Leopard_rangeOfData:(NSData *)dataToFind options:(NSDataSearchOptions)mask range:(NSRange)searchRange {
    NSUInteger patternLength = [dataToFind length];
    NSUInteger selfLength = [self length];
    
    if (searchRange.location > selfLength || NSMaxRange(searchRange) > selfLength)
        [NSException raise:NSRangeException format:@"Range {%lu,%lu} exceeds length %lu", (unsigned long)searchRange.location, (unsigned long)searchRange.length, (unsigned long)selfLength];
    
    // This test is a nice shortcut, but it's also necessary to avoid crashing: zero-length NSDatas will sometimes(?) return NULL for their bytes pointer, and the resulting pointer arithmetic can underflow.
    if (patternLength == 0 || patternLength > searchRange.length)
        return NSMakeRange(NSNotFound, 0);
    
    const void *patternBytes = [dataToFind bytes];
    const unsigned char *selfBufferStart, *selfPtr, *selfPtrEnd, *selfPtrMax;
    const unsigned char firstPatternByte = *(const char *)patternBytes;
    BOOL backward = (mask & NSDataSearchBackwards) != 0;
    BOOL anchored = (mask & NSDataSearchAnchored) != 0;
    
    selfBufferStart = [self bytes];
    selfPtrMax = selfBufferStart + NSMaxRange(searchRange) + 1 - patternLength;
    if (backward) {
        selfPtr = selfPtrMax - 1;
        selfPtrEnd = selfBufferStart + searchRange.location - 1;
    } else {
        selfPtr = selfBufferStart + searchRange.location;
        selfPtrEnd = selfPtrMax;
    }
    
    for (;;) {
        if (memcmp(selfPtr, patternBytes, patternLength) == 0)
            return NSMakeRange(selfPtr - selfBufferStart, patternLength);
        
        if (anchored)
            break;
        
        if (backward) {
            do {
                selfPtr--;
            } while (*selfPtr != firstPatternByte && selfPtr > selfPtrEnd);
            if (*selfPtr != firstPatternByte)
                break;
        } else {
            selfPtr++;
            if (selfPtr == selfPtrEnd)
                break;
            selfPtr = memchr(selfPtr, firstPatternByte, (selfPtrMax - selfPtr));
            if (selfPtr == NULL)
                break;
        }
    }
    return NSMakeRange(NSNotFound, 0);
}

- (NSString *)md5String {
    CC_MD5_CTX md5context;
    NSUInteger signatureLength = CC_MD5_DIGEST_LENGTH;
    unsigned char signature[signatureLength];
    NSUInteger blockSize = 4096;
    char buffer[blockSize];
    NSUInteger length = [self length];
    NSRange range = NSMakeRange(0, MIN(blockSize, length));
    
    CC_MD5_Init(&md5context);
    while (range.length > 0) {
        [self getBytes:buffer range:range];
        CC_MD5_Update(&md5context, (const void *)buffer, (CC_LONG)range.length);
        range.location = NSMaxRange(range);
        range.length = MIN(blockSize, length - range.location);
    }
    CC_MD5_Final(signature, &md5context);
    
    NSMutableString *md5String = [NSMutableString stringWithCapacity:signatureLength];
    NSUInteger i;
    
    for (i = 0; i < signatureLength; i++)
        [md5String appendFormat:@"%02x", signature[i]];
    
    return md5String;
}

// The following code is taken and modified from Matt Gallagher's code at http://cocoawithlove.com/2009/06/base64-encoding-options-on-mac-and.html

// Mapping from 6 bit pattern to ASCII character.
static unsigned char base64EncodeTable[65] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

// Definition for "masked-out" areas of the     base64DecodeTable mapping
#define xx 65

// Mapping from ASCII character to 6 bit pattern.
static unsigned char base64DecodeTable[256] =
{
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 62, xx, xx, xx, 63, 
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, xx, xx, xx, xx, xx, xx, 
    xx,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, xx, xx, xx, xx, xx, 
    xx, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
};

// Fundamental sizes of the binary and base64 encode/decode units in bytes
#define BINARY_UNIT_SIZE 3
#define BASE64_UNIT_SIZE 4

- (id)initWithBase64String:(NSString *)base64String {
    NSData *data = [base64String dataUsingEncoding:NSASCIIStringEncoding];
    size_t length = [data length];
    const unsigned char *inputBuffer = (const unsigned char *)[data bytes];
    size_t outputBufferSize = (length / BASE64_UNIT_SIZE) * BINARY_UNIT_SIZE;
    unsigned char *outputBuffer = (unsigned char *)malloc(outputBufferSize);
    
    size_t i = 0, j = 0;
    while (i < length) {
		// Accumulate 4 valid characters (ignore everything else)
		unsigned char accumulated[BASE64_UNIT_SIZE];
		size_t accumulateIndex = 0;
		while (i < length) {
			unsigned char decode = base64DecodeTable[inputBuffer[i++]];
			if (decode != xx) {
				accumulated[accumulateIndex] = decode;
				accumulateIndex++;
				
				if (accumulateIndex == BASE64_UNIT_SIZE)
					break;
			}
		}
		
		// Store the 6 bits from each of the 4 characters as 3 bytes
		outputBuffer[j] = (accumulated[0] << 2) | (accumulated[1] >> 4);
		outputBuffer[j + 1] = (accumulated[1] << 4) | (accumulated[2] >> 2);
		outputBuffer[j + 2] = (accumulated[2] << 6) | accumulated[3];
		j += accumulateIndex - 1;
    }
    
    NSData *result = [self initWithBytes:outputBuffer length:j];
    
    free(outputBuffer);
    
    return result;
}

- (NSString *)base64StringWithNewlines:(BOOL)encodeWithNewlines {
    size_t length = [self length];
    const unsigned char *inputBuffer = (const unsigned char *)[self bytes];
    
    #define MAX_NUM_PADDING_CHARS 2
    #define OUTPUT_LINE_LENGTH 64
    #define INPUT_LINE_LENGTH ((OUTPUT_LINE_LENGTH / BASE64_UNIT_SIZE) * BINARY_UNIT_SIZE)
    
    // Byte accurate calculation of final buffer size
    size_t outputBufferSize = ((length / BINARY_UNIT_SIZE) + ((length % BINARY_UNIT_SIZE) ? 1 : 0)) * BASE64_UNIT_SIZE;
    if (encodeWithNewlines)
		outputBufferSize += (outputBufferSize / OUTPUT_LINE_LENGTH);
    
    // Include space for a terminating zero
    outputBufferSize += 1;

    // Allocate the output buffer
    char *outputBuffer = (char *)malloc(outputBufferSize);
    if (outputBuffer == NULL)
		return NULL;

    size_t i = 0;
    size_t j = 0;
    const size_t lineLength = encodeWithNewlines ? INPUT_LINE_LENGTH : length;
    size_t lineEnd = lineLength;
    
    while (true) {
		if (lineEnd > length)
			lineEnd = length;

		for (; i + BINARY_UNIT_SIZE - 1 < lineEnd; i += BINARY_UNIT_SIZE) {
			// Inner loop: turn 48 bytes into 64 base64 characters
			outputBuffer[j++] = base64EncodeTable[(inputBuffer[i] & 0xFC) >> 2];
			outputBuffer[j++] = base64EncodeTable[((inputBuffer[i] & 0x03) << 4) | ((inputBuffer[i + 1] & 0xF0) >> 4)];
			outputBuffer[j++] = base64EncodeTable[((inputBuffer[i + 1] & 0x0F) << 2) | ((inputBuffer[i + 2] & 0xC0) >> 6)];
			outputBuffer[j++] = base64EncodeTable[inputBuffer[i + 2] & 0x3F];
		}
		
		if (lineEnd == length)
			break;
		
		// Add the newline
		outputBuffer[j++] = '\n';
		lineEnd += lineLength;
    }
    
    if (i + 1 < length) {
		// Handle the single '=' case
		outputBuffer[j++] = base64EncodeTable[(inputBuffer[i] & 0xFC) >> 2];
		outputBuffer[j++] = base64EncodeTable[((inputBuffer[i] & 0x03) << 4) | ((inputBuffer[i + 1] & 0xF0) >> 4)];
		outputBuffer[j++] = base64EncodeTable[(inputBuffer[i + 1] & 0x0F) << 2];
		outputBuffer[j++] = '=';
    } else if (i < length) {
		// Handle the double '=' case
		outputBuffer[j++] = base64EncodeTable[(inputBuffer[i] & 0xFC) >> 2];
		outputBuffer[j++] = base64EncodeTable[(inputBuffer[i] & 0x03) << 4];
		outputBuffer[j++] = '=';
		outputBuffer[j++] = '=';
    }
    outputBuffer[j] = 0;
    
    NSString *result = [[[NSString alloc] initWithBytes:outputBuffer length:j encoding:NSASCIIStringEncoding] autorelease];
    
    free(outputBuffer);
    
    return result;
}

- (NSString *)base64String {
    return [self base64StringWithNewlines:NO];
}

#pragma mark Templating support

- (NSString *)xmlString {
    return [self base64StringWithNewlines:YES];
}

#pragma mark Scripting support

+ (NSData *)dataWithPointAsQDPoint:(NSPoint)point {
    Point qdPoint = SKQDPointFromNSPoint(point);
    return [self dataWithBytes:&qdPoint length:sizeof(Point)];
}

+ (NSData *)dataWithRectAsQDRect:(NSRect)rect {
    Rect qdRect = SKQDRectFromNSRect(rect);
    return [self dataWithBytes:&qdRect length:sizeof(Rect)];
}

- (NSPoint)pointValueAsQDPoint {
    NSPoint point = NSZeroPoint;
    if ([self length] == sizeof(Point)) {
        const Point *qdPoint = (const Point *)[self bytes];
        point = SKNSPointFromQDPoint(*qdPoint);
    }
    return point;
}

- (NSRect)rectValueAsQDRect {
    NSRect rect = NSZeroRect;
    if ([self length] == sizeof(Rect)) {
        const Rect *qdRect = (const Rect *)[self bytes];
        rect = SKNSRectFromQDRect(*qdRect);
    }
    return rect;
}

+ (id)scriptingPdfWithDescriptor:(NSAppleEventDescriptor *)descriptor {
    return [descriptor data];
}

- (id)scriptingPdfDescriptor {
    return [NSAppleEventDescriptor descriptorWithDescriptorType:'PDF ' data:self];
}

+ (id)scriptingTiffPictureWithDescriptor:(NSAppleEventDescriptor *)descriptor {
    return [descriptor data];
}

- (id)scriptingTiffPictureDescriptor {
    return [NSAppleEventDescriptor descriptorWithDescriptorType:'TIFF' data:self];
}

+ (void)load {
    // this should do nothing on Snow Leopard
    SKAddInstanceMethodImplementationFromSelector(self, @selector(rangeOfData:options:range:), @selector(Leopard_rangeOfData:options:range:));
}

@end
