//
//  DCAudioEffectMeter.m
//  MediaPlayerDemo
//
//  Created by David Cairns on 5/22/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import "DCAudioEffectMeter.h"

@interface DCAudioEffectMeter ()
@property(nonatomic, assign)CGFloat peakDb;
@property(nonatomic, assign)CGFloat previousRectifiedSampleValue;
@end

@implementation DCAudioEffectMeter
@synthesize peakDb = _peakDb;
@synthesize previousRectifiedSampleValue = _previousRectifiedSampleValue;

- (void)processSamplesInBuffer:(SInt16 *)buffer numSamples:(NSInteger)numSamples {
	for(NSInteger sampleIndex = 0; sampleIndex < numSamples; sampleIndex++) {
		// Reset our peak reading.
		self.peakDb = 0.0f;
		
		// Rectify the sample (make it positive).
		Float32 rectifiedSample = fabsf(buffer[sampleIndex]);
		
		// Low-pass filter the recitified amplitude signal.
		const float kLowPassTimeDelay = 0.001f;
		Float32 filteredSampleValue = kLowPassTimeDelay * rectifiedSample + (1.0f - kLowPassTimeDelay) * self.previousRectifiedSampleValue;
		self.previousRectifiedSampleValue = rectifiedSample;
		
		// Convert from amplitude to decibels.
		Float32 db = 20.0f * log10f(filteredSampleValue);
		
		// See if this is a new max value.
		self.peakDb = MAX(self.peakDb, db);
	}
}


#pragma mark -
- (CGFloat)meterLevel {
	// TODO: If we haven't processed any samples in more than a couple miliseconds, our meter result should be zero. --DRC
//	if(???) {
//		return 0.0f;
//	}
	return self.peakDb;
}

@end
