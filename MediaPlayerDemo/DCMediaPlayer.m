//
//  DCMediaPlayer.m
//  MediaPlayerDemo
//
//  Created by David Cairns on 4/5/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import "DCMediaPlayer.h"
#import <AVFoundation/AVFoundation.h>

#pragma mark -
#pragma mark Audio-Processing Callbacks
OSStatus audioInputCallback(void *inRefCon, 
							AudioUnitRenderActionFlags *ioActionFlags, 
							const AudioTimeStamp *inTimeStamp, 
							UInt32 inBusNumber, 
							UInt32 inNumberFrames, 
							AudioBufferList *ioData) {
	
	DCMusicPlaybackState *state = (DCMusicPlaybackState *)inRefCon;
	int samplesToCopy = ioData->mBuffers[0].mDataByteSize / sizeof(SInt16);
	SInt16 *targetBuffer = (SInt16 *)ioData->mBuffers[0].mData;
	
	// Reset our peak reading.
	state->peakDb = 0.0f;
	
	[state->audioBufferLock lock];
	
	while(samplesToCopy > 0) {
		// Determine how many samples we can read.
		int sampleCount = MIN(samplesToCopy, TPCircularBufferFillCountContiguous(state->ringBufferRecord));
		if(0 == sampleCount) {
			break;
		}
		
		// Get the pointer to read from.
		SInt16 *sourceBuffer = state->audioDataBuffer + state->ringBufferRecord->tail;
		
		// Process the samples in this buffer.
		for(SInt16 sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++) {
			AudioSampleType sample = sourceBuffer[sampleIndex];
			
			if(state->useEffects) {
				// Do our low-pass filtering.
				// Convert from SInt16 [-32768, 32767] to float [-1, 1].
				float fSample = ((float)sample / (float)(32767));
				
				// 2-pole, cutoff: 10KHz
				// NOTE: This code was taken from the filter generator at http://www-users.cs.york.ac.uk/~fisher/mkfilter/
				state->xv[0] = state->xv[1]; state->xv[1] = state->xv[2];
				state->xv[2] = fSample / 3.978041310e+00;
				state->yv[0] = state->yv[1]; state->yv[1] = state->yv[2];
				state->yv[2] = (state->xv[0] + state->xv[2]) + 2.0f * state->xv[1]
				+ (-0.1767613657 * state->yv[0]) + (0.1712413904 * state->yv[1]);
				
				// Convert back from float [-1, 1] to SInt16 [-32768, 32767].
				sourceBuffer[sampleIndex] = state->yv[2] * (float)32767;
			}
			
			if(state->meteringEnabled) {
				// Rectify the sample (make it positive).
				Float32 rectifiedSample = fabsf(sample);
				
				// Low-pass filter the recitified amplitude signal.
				const float kLowPassTimeDelay = 0.001f;
				Float32 filteredSampleValue = kLowPassTimeDelay * rectifiedSample + (1.0f - kLowPassTimeDelay) * state->previousRectifiedSampleValue;
				state->previousRectifiedSampleValue = rectifiedSample;
				
				// Convert from amplitude to decibels.
				Float32 db = 20.0f * log10f(filteredSampleValue);
				
				// See if this is a new max value.
				state->peakDb = MAX(state->peakDb, db);
			}
		}
		
		// Do the actual copy.
		memcpy(targetBuffer, sourceBuffer, sampleCount * sizeof(SInt16));
		
		// Advance our pointers.
		targetBuffer += sampleCount;
		samplesToCopy -= sampleCount;
		TPCircularBufferConsume(state->ringBufferRecord, sampleCount);
	}
	
	[state->audioBufferLock unlock];
	
	return noErr;
}



@interface DCMediaPlayer ()
- (NSURL *)_urlForExportingKey:(NSString *)itemKey;
- (void)_setUpAudioUnits;
- (void)_destroyBuffers;
- (void)_setUpBuffers;
- (void)_startProducerTimer;
@end

@implementation DCMediaPlayer
@synthesize mediaURL = _mediaURL;
@synthesize isPlaying = _isPlaying;

- (void)dealloc {
	[_producerTimer invalidate];
	
	// Deallocate other state.
	if(_musicPlaybackState.audioDataBuffer) {
		free(_musicPlaybackState.audioDataBuffer);
	}
	if(_musicPlaybackState.scratchBuffer) {
		free(_musicPlaybackState.scratchBuffer);
	}
	
	[_musicPlaybackState.audioBufferLock release];
	
	self.mediaURL = nil;
	[super dealloc];
}


#pragma mark -
- (BOOL)useEffects {
	return _musicPlaybackState.useEffects;
}
- (void)setUseEffects:(BOOL)useEffects {
	_musicPlaybackState.useEffects = useEffects;
}

- (BOOL)isPlaying {
	return _isPlaying;
}

- (BOOL)meteringEnabled {
	return _musicPlaybackState.meteringEnabled;
}
- (void)setMeteringEnabled:(BOOL)meteringEnabled {
	_musicPlaybackState.meteringEnabled = meteringEnabled;
}

- (CGFloat)meterLevel {
	if(!self.isPlaying) {
		return 0.0f;
	}
	return _musicPlaybackState.peakDb;
}


#pragma mark -
- (NSURL *)_urlForExportingKey:(NSString *)itemKey {
	// Get the file path.
	NSString *documentsDirectoryPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
	NSString *exportFilePath = [documentsDirectoryPath stringByAppendingPathComponent:[itemKey stringByAppendingPathExtension:@"caf"]];
	
	// Make sure the file path we want to export to doesn't already exist.
	if([[NSFileManager defaultManager] fileExistsAtPath:exportFilePath]) {
		NSError *error = nil;
		if(![[NSFileManager defaultManager] removeItemAtPath:exportFilePath error:&error]) {
			NSLog(@"Failed to clear out export file, with error: %@", error);
		}
	}
	
	return [NSURL fileURLWithPath:exportFilePath];
}

- (void)play {
	// Make sure we have a URL to play.
	if(!self.mediaURL) {
		NSLog(@"DCMediaPlayer: tried to play without a URL!");
		return;
	}
	if(!_isInitialized) {
		[self _setUpAudioUnits];
	}
	
	// Reset our play state.
	_musicPlaybackState.peakDb = 0.0f;
	_musicPlaybackState.audioFileOffset = 0;
	
	[self _startProducerTimer];
	
	OSStatus startErr = AudioOutputUnitStart(_remoteIOUnit);
	if(startErr) {
		NSLog(@"Couldn't start RIO unit, error: %ld", startErr);
		return;
	}
	
	[self willChangeValueForKey:@"isPlaying"];
	_isPlaying = YES;
	[self didChangeValueForKey:@"isPlaying"];
}
- (void)stop {
	if(_isInitialized) {
		OSStatus err = AudioOutputUnitStop(_remoteIOUnit);
		if(err) {
			NSLog(@"Failed to stop audio unit. Just keep going? (err: %ld", err);
		}
		err = AudioUnitUninitialize(_remoteIOUnit);
		if(err) {
			NSLog(@"Failed to uninitialize audio unit. Just keep going? (err: %ld", err);
		}
		
		NSLog(@"Killing producer timer!");
		// Stop our producer timer.
		[_producerTimer invalidate];
		_producerTimer = nil;
		
		// Deallocate our buffers.
		[self _destroyBuffers];
	}
	_isInitialized = NO;
	
	[self willChangeValueForKey:@"isPlaying"];
	_isPlaying = NO;
	[self didChangeValueForKey:@"isPlaying"];
}


#pragma mark -
#pragma mark set up AudioUnits
- (void)_setUpAudioUnits {
	// Describe our RIO unit.
	AudioComponentDescription audioCompDesc;
	audioCompDesc.componentType = kAudioUnitType_Output;
	audioCompDesc.componentSubType = kAudioUnitSubType_RemoteIO;
	audioCompDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
	audioCompDesc.componentFlags = 0;
	audioCompDesc.componentFlagsMask = 0;
	
	// Get the RIO unit from the audio component manager.
	AudioComponent rioComponent = AudioComponentFindNext(NULL, &audioCompDesc);
	OSStatus setupErr = AudioComponentInstanceNew(rioComponent, &_remoteIOUnit);
	NSAssert(noErr == setupErr, @"Couldn't get RIO unit instance");
	
	// Enable output on bus 0 for our RIO unit, which will output to hardware.
	UInt32 oneFlag = 1;
	AudioUnitElement bus0 = 0;
	setupErr = AudioUnitSetProperty(_remoteIOUnit, 
									kAudioOutputUnitProperty_EnableIO, 
									kAudioUnitScope_Output, 
									bus0, 
									&oneFlag, 
									sizeof(oneFlag));
	NSAssert(noErr == setupErr, @"Couldn't enable RIO output");
	
	
	// Set up an asbd in the iphone canonical format.
	AudioStreamBasicDescription lcpmStreamDescription;
	memset(&lcpmStreamDescription, 0, sizeof (lcpmStreamDescription));
	lcpmStreamDescription.mSampleRate = 44100;
	lcpmStreamDescription.mFormatID = kAudioFormatLinearPCM;
	lcpmStreamDescription.mFormatFlags = kAudioFormatFlagsCanonical;
	lcpmStreamDescription.mBytesPerPacket = 4;
	lcpmStreamDescription.mFramesPerPacket = 1;
	lcpmStreamDescription.mBytesPerFrame = 4;
	lcpmStreamDescription.mChannelsPerFrame = 2;
	lcpmStreamDescription.mBitsPerChannel = 16;
	
	// Set format for output (bus 0) on RIO unit's input scope.
	setupErr = AudioUnitSetProperty(_remoteIOUnit, 
									kAudioUnitProperty_StreamFormat, 
									kAudioUnitScope_Input, 
									bus0, 
									&lcpmStreamDescription, 
									sizeof(lcpmStreamDescription));
	NSAssert(noErr == setupErr, @"Couldn't set ASBD for RIO on input scope / bus 0");
	
	
	// Set our asbd for mic input (on our RIO unit).
	AudioUnitElement bus1 = 1;
	setupErr = AudioUnitSetProperty(_remoteIOUnit, 
									kAudioUnitProperty_StreamFormat, 
									kAudioUnitScope_Output, 
									bus1, 
									&lcpmStreamDescription, 
									sizeof(lcpmStreamDescription));
	NSAssert(noErr == setupErr, @"Couldn't set ASBD for RIO on output scope / bus 1");
	
	
	// Get an Audio File representation for the song.
	setupErr = AudioFileOpenURL((CFURLRef)self.mediaURL, kAudioFileReadPermission, 0, &_musicPlaybackState.audioFile);
	NSAssert(noErr == setupErr, @"Couldn't open audio file");
	
	// Read in the entire audio file (NOT recommended). It would be better to use a ring buffer: thread or timer fills, render callback drains.
	UInt32 audioDataByteCountSize = sizeof(_musicPlaybackState.audioFileSize);
	setupErr = AudioFileGetProperty(_musicPlaybackState.audioFile, kAudioFilePropertyAudioDataByteCount, &audioDataByteCountSize, &_musicPlaybackState.audioFileSize);
	NSAssert(noErr == setupErr, @"Couldn't get size property");
	
	// Get the audio file's stream description.
	AudioStreamBasicDescription audioFileStreamDescription;
	UInt32 audioStreamDescriptionSize = sizeof(audioFileStreamDescription);
	setupErr = AudioFileGetProperty(_musicPlaybackState.audioFile, kAudioFilePropertyDataFormat, &audioStreamDescriptionSize, &audioFileStreamDescription);
	NSAssert(noErr == setupErr, @"Couldn't get file asbd");
	
	_musicPlaybackState.audioStreamDescription = audioFileStreamDescription;
	
	// Clean up our music playback state structure if it's already been in use.
	[self _destroyBuffers];
	
	// Make sure our buffers are set up!
	[self _setUpBuffers];
	
	// Set the stream description for our RIO unit's bus 0 input.
	setupErr = AudioUnitSetProperty(_remoteIOUnit, 
									kAudioUnitProperty_StreamFormat, 
									kAudioUnitScope_Input, 
									0, 
									&audioFileStreamDescription, 
									sizeof(audioFileStreamDescription));
	NSAssert(noErr == setupErr, @"Couldn't set ASBD for remote IO unit on input scope / bus 0");
	
	
	// Connect our RIO unit's input bus 0 to our music player callback.
	AURenderCallbackStruct musicPlayerCallbackStruct;
	musicPlayerCallbackStruct.inputProc = audioInputCallback;
	musicPlayerCallbackStruct.inputProcRefCon = &_musicPlaybackState;
	setupErr = AudioUnitSetProperty(_remoteIOUnit, 
									kAudioUnitProperty_SetRenderCallback, 
									kAudioUnitScope_Global, 
									0, 
									&musicPlayerCallbackStruct, 
									sizeof(musicPlayerCallbackStruct));
	NSAssert(noErr == setupErr, @"Couldn't set RIO unit's render callback on bus 0 input");
	
	setupErr = AudioUnitInitialize(_remoteIOUnit);
	NSAssert(setupErr == noErr, @"Couldn't initialize RIO unit");
	
	_isInitialized = YES;
}

#pragma mark -
#pragma mark Producer logic
- (void)_destroyBuffers {
	[_musicPlaybackState.audioBufferLock lock];
	
	if(_musicPlaybackState.audioDataBuffer) {
		free(_musicPlaybackState.audioDataBuffer);
		_musicPlaybackState.audioDataBuffer = NULL;
	}
	if(_musicPlaybackState.scratchBuffer) {
		free(_musicPlaybackState.scratchBuffer);
		_musicPlaybackState.scratchBuffer = NULL;
	}
	if(_musicPlaybackState.ringBufferRecord) {
		TPCircularBufferClear(_musicPlaybackState.ringBufferRecord);
		free(_musicPlaybackState.ringBufferRecord);
		_musicPlaybackState.ringBufferRecord = NULL;
	}
	
	[_musicPlaybackState.audioBufferLock unlock];
}
- (void)_setUpBuffers {
	if(!_musicPlaybackState.audioBufferLock) {
		_musicPlaybackState.audioBufferLock = [[NSLock alloc] init];
	}
	
	[_musicPlaybackState.audioBufferLock lock];
	
	// Set up our music playback state structure (including our ring buffer).
	if(!_musicPlaybackState.audioDataBuffer) {
		_musicPlaybackState.audioDataBuffer = (AudioSampleType *)malloc(kRingBufferLength * sizeof(SInt16));
		memset(_musicPlaybackState.audioDataBuffer, 0, kRingBufferLength * sizeof(SInt16));
	}
	
	if(!_musicPlaybackState.scratchBuffer) {
		_musicPlaybackState.scratchBuffer = (AudioSampleType *)malloc(kScratchBufferLength * sizeof(SInt16));
		memset(_musicPlaybackState.scratchBuffer, 0, kScratchBufferLength * sizeof(SInt16));
	}
	
	if(!_musicPlaybackState.ringBufferRecord) {
		_musicPlaybackState.ringBufferRecord = (TPCircularBufferRecord *)malloc(sizeof(TPCircularBufferRecord));
		TPCircularBufferInit(_musicPlaybackState.ringBufferRecord, kRingBufferLength);
	}
	
	memset(_musicPlaybackState.xv, 0, sizeof(_musicPlaybackState.xv));
	memset(_musicPlaybackState.yv, 0, sizeof(_musicPlaybackState.yv));
	
	[_musicPlaybackState.audioBufferLock unlock];
}
- (void)_startProducerTimer {
	// Make sure all of our buffers are set up!
	[self _setUpBuffers];
	
	[_producerTimer invalidate];
	_producerTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(_producerTimerFired:) userInfo:nil repeats:YES];
}
- (void)_producerTimerFired:(NSTimer *)timer {
	// Make sure we're not going to overflow our ring buffer.
	int numEntriesOpenForWriting = TPCircularBufferSpace(_musicPlaybackState.ringBufferRecord);
	
	// Make sure the file has been set up.
	if(!_musicPlaybackState.audioFile) {
		return;
	}
	
	// Read data from the audio file into our temporary (scratch) buffer.
	UInt32 numItemsToRead = MIN(kScratchBufferLength, numEntriesOpenForWriting);
	UInt32 bytesRead = MIN(numItemsToRead * sizeof(SInt16), _musicPlaybackState.audioFileSize - _musicPlaybackState.audioFileOffset);
	OSStatus err = AudioFileReadBytes(_musicPlaybackState.audioFile, false, _musicPlaybackState.audioFileOffset, &bytesRead, _musicPlaybackState.scratchBuffer);
	if(err) {
		NSLog(@"WARNING: Failed to read from file, err: %ld", err);
		[self stop];
		return;
	}
	
	// Advance our read offset.
	_musicPlaybackState.audioFileOffset += bytesRead;
	
	// Check to see if we should loop (continuing playing from the beginning of the file).
	if(_musicPlaybackState.audioFileOffset >= _musicPlaybackState.audioFileSize) {
		_musicPlaybackState.audioFileOffset = 0;
	}
	
	// Actually copy the data into the ring buffer.
	[_musicPlaybackState.audioBufferLock lock];
	
	// Make sure our buffers still exist.
	if(_musicPlaybackState.ringBufferRecord && _musicPlaybackState.audioDataBuffer && _musicPlaybackState.scratchBuffer) {
		int samplesRead = bytesRead / sizeof(SInt16);
		TPCircularBufferCopy(_musicPlaybackState.ringBufferRecord, _musicPlaybackState.audioDataBuffer, _musicPlaybackState.scratchBuffer, samplesRead, sizeof(SInt16));
	}
	
	[_musicPlaybackState.audioBufferLock unlock];
}

@end
