//
//  DCMediaPlayer.h
//  MediaPlayerDemo
//
//  Created by David Cairns on 4/5/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "TPCircularBuffer.h"

@interface DCMediaPlayer : NSObject {
	BOOL _isPlaying;
	
	BOOL _isInitialized;
	AudioUnit _remoteIOUnit;
	
	// Playback state.
	BOOL _initializedRingBuffer;
	TPCircularBufferRecord *_ringBufferRecord;
	AudioSampleType *_audioDataBuffer;
	AudioSampleType *_scratchBuffer;
	UInt64 _audioFileSize;
	SInt64 _audioFileOffset;
	AudioFileID _audioFile;
	NSLock *_audioBufferLock;
	
	AudioStreamBasicDescription _audioStreamDescription;
	
	// Low-pass filter.
	BOOL _useEffects;
	float _xv[3];
	float _yv[3];
	
	// Amplitude measuring.
	BOOL _meteringEnabled;
	float _previousRectifiedSampleValue;
	float _peakDb;
	
	NSTimer *_producerTimer;
}

@property(nonatomic, retain)NSURL *mediaURL;
@property(nonatomic, assign)BOOL useEffects;

- (void)play;
- (void)stop;

@property(nonatomic, readonly)BOOL isPlaying;

@property(nonatomic, assign)BOOL meteringEnabled;
@property(nonatomic, readonly)CGFloat meterLevel;

@end
