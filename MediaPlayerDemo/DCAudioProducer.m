//
//  DCAudioProducer.m
//  MediaPlayerDemo
//
//  Created by David Cairns on 5/24/11.
//  Copyright 2011 ngmoco:). All rights reserved.
//

#import "DCAudioProducer.h"

@implementation DCAudioProducer
@synthesize audioStreamDescription = _audioStreamDescription;

- (NSInteger)renderAudioIntoBuffer:(SInt16 *)buffer numSamples:(NSInteger)numSamples {
	// Default implementation is a no-op.
	return 0;
}

@end
