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

typedef struct {
	BOOL initializedRingBuffer;
	TPCircularBufferRecord *ringBufferRecord;
	AudioSampleType *audioDataBuffer;
	AudioSampleType *scratchBuffer;
	UInt64 audioFileSize;
	SInt64 audioFileOffset;
	AudioFileID audioFile;
	NSLock *audioBufferLock;
	
	AudioStreamBasicDescription audioStreamDescription;
	
	// Low-pass filter.
	BOOL useEffects;
	float xv[3];
	float yv[3];
	
	// Amplitude measuring.
	BOOL meteringEnabled;
	float previousRectifiedSampleValue;
	float peakDb;
} DCMusicPlaybackState;


@interface DCMediaPlayer : NSObject {
	BOOL _isPlaying;
	
	BOOL _isInitialized;
	AudioUnit _remoteIOUnit;
	DCMusicPlaybackState *_musicPlaybackState;
	
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
