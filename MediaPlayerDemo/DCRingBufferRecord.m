//
//  DCRingBufferRecord.m
//  MediaPlayerDemo
//
//  Created by David Cairns on 5/22/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import "DCRingBufferRecord.h"

@interface DCRingBufferRecord ()
@property(nonatomic, assign)NSInteger length;
@property(nonatomic, assign)NSInteger head;
@property(nonatomic, assign)NSInteger tail;
@property(nonatomic, assign)NSInteger fillCount;
@end

@implementation DCRingBufferRecord
@synthesize length = _length;
@synthesize head = _head;
@synthesize tail = _tail;
@synthesize fillCount = _fillCount;

- (id)initWithLength:(NSInteger)length {
	if((self = [super init])) {
		self.length = length;
	}
	return self;
}

#pragma mark -
- (NSInteger)fillCountContiguous {
    return MIN(self.fillCount, self.length - self.tail);
}

- (NSInteger)space {
	return self.length - self.fillCount;
}
- (NSInteger)spaceContiguous {
	return MIN(self.length - self.fillCount, self.length - self.head);
}

- (void)produceAmount:(NSInteger)amount {
    self.head = (self.head + amount) % self.length;
    self.fillCount += amount;
}
- (void)consumeAmount:(NSInteger)amount {
    self.tail = (self.tail + amount) % self.length;
    self.fillCount -= amount;
}

- (void)clear {
    self.tail = self.head;
    self.fillCount = 0;
}
- (NSInteger)copyNumElements:(NSInteger)numElements ofSize:(NSInteger)elementSize fromBuffer:(void *)source toBuffer:(void *)destination {
	int copied = 0;
	while(numElements > 0) {
		int space = [self spaceContiguous];
		if(0 == space) {
			return copied;
		}

		int toCopy = MIN(numElements, space);
		int bytesToCopy = toCopy * elementSize;
		memcpy(destination + (elementSize * self.head), source, bytesToCopy);
		
		source += bytesToCopy;
		numElements -= toCopy;
		copied += bytesToCopy;
		[self produceAmount:toCopy];
	}
	return copied;
}

@end
