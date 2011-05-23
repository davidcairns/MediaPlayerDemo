//
//  DCRingBufferRecord.h
//  MediaPlayerDemo
//
//	Basically an Objective-C rewrite of Michael Tyson's Circular Buffer implementation:
//	http://atastypixel.com/blog/a-simple-fast-circular-buffer-implementation-for-audio-processing/
//
//  Created by David Cairns on 5/22/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DCRingBufferRecord : NSObject {
	
}

- (id)initWithLength:(NSInteger)length;
- (NSInteger)length;

- (NSInteger)fillCount;
- (NSInteger)fillCountContiguous;

- (NSInteger)space;
- (NSInteger)spaceContiguous;

- (NSInteger)head;
- (NSInteger)tail;

- (void)produceAmount:(NSInteger)amount;
- (void)consumeAmount:(NSInteger)amount;

- (void)clear;
- (NSInteger)copyNumElements:(NSInteger)numElements ofSize:(NSInteger)elementSize fromBuffer:(void *)source toBuffer:(void *)destination;

@end
