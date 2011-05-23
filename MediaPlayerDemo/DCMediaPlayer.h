//
//  DCMediaPlayer.h
//  MediaPlayerDemo
//
//  Created by David Cairns on 4/5/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#define ENABLE_POST_PROCESSING 1

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "DCFileProducer.h"

@interface DCMediaPlayer : NSObject {
	BOOL _isPlaying;
	
	BOOL _isInitialized;
	AudioUnit _remoteIOUnit;
	
	// Playback state.
	DCFileProducer *_fileProducer;
	
	AudioStreamBasicDescription _audioStreamDescription;
	
#if ENABLE_POST_PROCESSING
	// Low-pass filter.
	BOOL _useEffects;
	float _xv[3];
	float _yv[3];
	
	// Amplitude measuring.
	BOOL _meteringEnabled;
	float _previousRectifiedSampleValue;
	float _peakDb;
#endif
}

@property(nonatomic, retain)NSURL *mediaURL;
@property(nonatomic, assign)BOOL useEffects;

- (void)play;
- (void)stop;

@property(nonatomic, readonly)BOOL isPlaying;

@property(nonatomic, assign)BOOL meteringEnabled;
@property(nonatomic, readonly)CGFloat meterLevel;

@end
