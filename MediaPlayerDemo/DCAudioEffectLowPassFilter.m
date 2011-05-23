//
//  DCAudioEffectLowPassFilter.m
//  MediaPlayerDemo
//
//  Created by David Cairns on 5/22/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import "DCAudioEffectLowPassFilter.h"

@implementation DCAudioEffectLowPassFilter

- (id)init {
	if((self = [super init])) {
		self.destructive = YES;
	}
	return self;
}

- (void)processSamplesInBuffer:(SInt16 *)buffer numSamples:(NSInteger)numSamples {
	for(NSInteger sampleIndex = 0; sampleIndex < numSamples; sampleIndex++) {
		// Do our low-pass filtering.
		// Convert from SInt16 [-32768, 32767] to float [-1, 1].
		float fSample = ((float)buffer[sampleIndex] / (float)(32767));
		
		// 2-pole, cutoff: 10KHz
		// NOTE: This code was taken from the filter generator at http://www-users.cs.york.ac.uk/~fisher/mkfilter/
		_xv[0] = _xv[1]; _xv[1] = _xv[2];
		_xv[2] = fSample / 3.978041310e+00;
		_yv[0] = _yv[1]; _yv[1] = _yv[2];
		_yv[2] = (_xv[0] + _xv[2]) + 2.0f * _xv[1] + (-0.1767613657 * _yv[0]) + (0.1712413904 * _yv[1]);
		
		// Convert back from float [-1, 1] to SInt16 [-32768, 32767].
		buffer[sampleIndex] = _yv[2] * (float)32767;
	}
}

@end
