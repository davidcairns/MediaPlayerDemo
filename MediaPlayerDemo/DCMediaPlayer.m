//
//  DCMediaPlayer.m
//  MediaPlayerDemo
//
//  Created by David Cairns on 4/5/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import "DCMediaPlayer.h"
#import <AVFoundation/AVFoundation.h>

#define kRingBufferLength (1 << 20) // 1M
#define kScratchBufferLength (64 << 10) // 64K


#pragma mark -
@interface DCMediaPlayer(Rendering)
- (OSStatus)_renderAudioIntoBufferList:(AudioBufferList *)bufferList timestamp:(const AudioTimeStamp *)timestamp bus:(UInt32)bus numFrames:(UInt32)numFrames flags:(AudioUnitRenderActionFlags *)flags;
@end
#pragma mark Audio-Processing Callbacks
OSStatus audioInputCallback(void *inRefCon, 
							AudioUnitRenderActionFlags *ioActionFlags, 
							const AudioTimeStamp *inTimeStamp, 
							UInt32 inBusNumber, 
							UInt32 inNumberFrames, 
							AudioBufferList *ioData) {
	
	DCMediaPlayer *mediaPlayer = (DCMediaPlayer *)inRefCon;
	return [mediaPlayer _renderAudioIntoBufferList:ioData timestamp:inTimeStamp bus:inBusNumber numFrames:inNumberFrames flags:ioActionFlags];
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
@synthesize useEffects = _useEffects;
@synthesize meteringEnabled = _meteringEnabled;

- (void)dealloc {
	[_producerTimer invalidate];
	self.mediaURL = nil;
	
	// Deallocate other state.
	if(_audioDataBuffer) {
		free(_audioDataBuffer);
	}
	if(_scratchBuffer) {
		free(_scratchBuffer);
	}
	[_audioBufferLock release];
	
	[super dealloc];
}


#pragma mark -
- (BOOL)isPlaying {
	return _isPlaying;
}

- (CGFloat)meterLevel {
	if(!self.isPlaying) {
		return 0.0f;
	}
	return _peakDb;
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
	_peakDb = 0.0f;
	_audioFileOffset = 0;
	
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
	setupErr = AudioFileOpenURL((CFURLRef)self.mediaURL, kAudioFileReadPermission, 0, &_audioFile);
	NSAssert(noErr == setupErr, @"Couldn't open audio file");
	
	// Read in the entire audio file (NOT recommended). It would be better to use a ring buffer: thread or timer fills, render callback drains.
	UInt32 audioDataByteCountSize = sizeof(_audioFileSize);
	setupErr = AudioFileGetProperty(_audioFile, kAudioFilePropertyAudioDataByteCount, &audioDataByteCountSize, &_audioFileSize);
	NSAssert(noErr == setupErr, @"Couldn't get size property");
	
	// Get the audio file's stream description.
	UInt32 audioStreamDescriptionSize = sizeof(_audioStreamDescription);
	setupErr = AudioFileGetProperty(_audioFile, kAudioFilePropertyDataFormat, &audioStreamDescriptionSize, &_audioStreamDescription);
	NSAssert(noErr == setupErr, @"Couldn't get file asbd");
	
	// Clean up our music playback state structure if it's already been in use.
	[self _destroyBuffers];
	
	// Make sure our buffers are set up!
	[self _setUpBuffers];
	
	// Set the stream description for our RIO unit's bus 0 input.
	setupErr = AudioUnitSetProperty(_remoteIOUnit, 
									kAudioUnitProperty_StreamFormat, 
									kAudioUnitScope_Input, 
									0, 
									&_audioStreamDescription, 
									sizeof(_audioStreamDescription));
	NSAssert(noErr == setupErr, @"Couldn't set ASBD for remote IO unit on input scope / bus 0");
	
	
	// Connect our RIO unit's input bus 0 to our music player callback.
	AURenderCallbackStruct musicPlayerCallbackStruct;
	musicPlayerCallbackStruct.inputProc = audioInputCallback;
	musicPlayerCallbackStruct.inputProcRefCon = self;
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
	[_audioBufferLock lock];
	
	if(_audioDataBuffer) {
		free(_audioDataBuffer);
		_audioDataBuffer = NULL;
	}
	if(_scratchBuffer) {
		free(_scratchBuffer);
		_scratchBuffer = NULL;
	}
	if(_ringBufferRecord) {
		TPCircularBufferClear(_ringBufferRecord);
		free(_ringBufferRecord);
		_ringBufferRecord = NULL;
	}
	
	[_audioBufferLock unlock];
}
- (void)_setUpBuffers {
	if(!_audioBufferLock) {
		_audioBufferLock = [[NSLock alloc] init];
	}
	
	[_audioBufferLock lock];
	
	if(!_audioDataBuffer) {
		_audioDataBuffer = (AudioSampleType *)malloc(kRingBufferLength * sizeof(SInt16));
		memset(_audioDataBuffer, 0, kRingBufferLength * sizeof(SInt16));
	}
	
	if(!_scratchBuffer) {
		_scratchBuffer = (AudioSampleType *)malloc(kScratchBufferLength * sizeof(SInt16));
		memset(_scratchBuffer, 0, kScratchBufferLength * sizeof(SInt16));
	}
	
	if(!_ringBufferRecord) {
		_ringBufferRecord = (TPCircularBufferRecord *)malloc(sizeof(TPCircularBufferRecord));
		TPCircularBufferInit(_ringBufferRecord, kRingBufferLength);
	}
	
	memset(_xv, 0, sizeof(_xv));
	memset(_yv, 0, sizeof(_yv));
	
	[_audioBufferLock unlock];
}
- (void)_startProducerTimer {
	// Make sure all of our buffers are set up!
	[self _setUpBuffers];
	
	[_producerTimer invalidate];
	_producerTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(_producerTimerFired:) userInfo:nil repeats:YES];
}
- (void)_producerTimerFired:(NSTimer *)timer {
	// Make sure we're not going to overflow our ring buffer.
	int numEntriesOpenForWriting = TPCircularBufferSpace(_ringBufferRecord);
	
	// Make sure the file has been set up.
	if(!_audioFile) {
		return;
	}
	
	// Read data from the audio file into our temporary (scratch) buffer.
	UInt32 numItemsToRead = MIN(kScratchBufferLength, numEntriesOpenForWriting);
	UInt32 bytesRead = MIN(numItemsToRead * sizeof(SInt16), _audioFileSize - _audioFileOffset);
	OSStatus err = AudioFileReadBytes(_audioFile, false, _audioFileOffset, &bytesRead, _scratchBuffer);
	if(err) {
		NSLog(@"WARNING: Failed to read from file, err: %ld", err);
		[self stop];
		return;
	}
	
	// Advance our read offset.
	_audioFileOffset += bytesRead;
	
	// Check to see if we should loop (continuing playing from the beginning of the file).
	if(_audioFileOffset >= _audioFileSize) {
		_audioFileOffset = 0;
	}
	
	// Actually copy the data into the ring buffer.
	[_audioBufferLock lock];
	
	// Make sure our buffers still exist.
	if(_ringBufferRecord && _audioDataBuffer && _scratchBuffer) {
		int samplesRead = bytesRead / sizeof(SInt16);
		TPCircularBufferCopy(_ringBufferRecord, _audioDataBuffer, _scratchBuffer, samplesRead, sizeof(SInt16));
	}
	
	[_audioBufferLock unlock];
}


#pragma mark -
- (OSStatus)_renderAudioIntoBufferList:(AudioBufferList *)bufferList timestamp:(const AudioTimeStamp *)timestamp bus:(UInt32)bus numFrames:(UInt32)numFrames flags:(AudioUnitRenderActionFlags *)flags {
	int samplesToCopy = bufferList->mBuffers[0].mDataByteSize / sizeof(SInt16);
	SInt16 *targetBuffer = (SInt16 *)bufferList->mBuffers[0].mData;
	
	// Reset our peak reading.
	_peakDb = 0.0f;
	
	[_audioBufferLock lock];
	
	while(samplesToCopy > 0) {
		// Determine how many samples we can read.
		int sampleCount = MIN(samplesToCopy, TPCircularBufferFillCountContiguous(_ringBufferRecord));
		if(0 == sampleCount) {
			break;
		}
		
		// Get the pointer to read from.
		SInt16 *sourceBuffer = _audioDataBuffer + _ringBufferRecord->tail;
		
		// Process the samples in this buffer.
		for(SInt16 sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++) {
			AudioSampleType sample = sourceBuffer[sampleIndex];
			
			if(_useEffects) {
				// Do our low-pass filtering.
				// Convert from SInt16 [-32768, 32767] to float [-1, 1].
				float fSample = ((float)sample / (float)(32767));
				
				// 2-pole, cutoff: 10KHz
				// NOTE: This code was taken from the filter generator at http://www-users.cs.york.ac.uk/~fisher/mkfilter/
				_xv[0] = _xv[1]; _xv[1] = _xv[2];
				_xv[2] = fSample / 3.978041310e+00;
				_yv[0] = _yv[1]; _yv[1] = _yv[2];
				_yv[2] = (_xv[0] + _xv[2]) + 2.0f * _xv[1]
				+ (-0.1767613657 * _yv[0]) + (0.1712413904 * _yv[1]);
				
				// Convert back from float [-1, 1] to SInt16 [-32768, 32767].
				sourceBuffer[sampleIndex] = _yv[2] * (float)32767;
			}
			
			if(_meteringEnabled) {
				// Rectify the sample (make it positive).
				Float32 rectifiedSample = fabsf(sample);
				
				// Low-pass filter the recitified amplitude signal.
				const float kLowPassTimeDelay = 0.001f;
				Float32 filteredSampleValue = kLowPassTimeDelay * rectifiedSample + (1.0f - kLowPassTimeDelay) * _previousRectifiedSampleValue;
				_previousRectifiedSampleValue = rectifiedSample;
				
				// Convert from amplitude to decibels.
				Float32 db = 20.0f * log10f(filteredSampleValue);
				
				// See if this is a new max value.
				_peakDb = MAX(_peakDb, db);
			}
		}
		
		// Do the actual copy.
		memcpy(targetBuffer, sourceBuffer, sampleCount * sizeof(SInt16));
		
		// Advance our pointers.
		targetBuffer += sampleCount;
		samplesToCopy -= sampleCount;
		TPCircularBufferConsume(_ringBufferRecord, sampleCount);
	}
	
	[_audioBufferLock unlock];
	
	return noErr;
}

@end
