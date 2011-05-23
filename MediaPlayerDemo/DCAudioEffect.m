//
//  DCAudioEffect.m
//  MediaPlayerDemo
//
//  Created by David Cairns on 5/22/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import "DCAudioEffect.h"

@implementation DCAudioEffect
@synthesize enabled = _enabled;
@synthesize destructive = _destructive;

- (id)init {
	if((self = [super init])) {
		self.enabled = YES;
	}
	return self;
}

- (void)processSamplesInBuffer:(SInt16 *)buffer numSamples:(NSInteger)numSamples {
	// Default is to do nothing -- so log an error!
	NSLog(@"ERROR: Attempting to use base audio effect!");
}

@end
