//
//  DCMediaPlayer.m
//  MediaPlayerDemo
//
//  Created by David Cairns on 4/5/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import "DCMediaPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import "DCFileProducer.h"

#pragma mark -
#pragma mark Audio-Processing Callbacks
@interface DCMediaPlayer(Rendering)
- (NSInteger)_renderAudioIntoBuffer:(SInt16 *)buffer numSamples:(NSInteger)numSamples;
@end
OSStatus audioInputCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
	DCMediaPlayer *mediaPlayer = (DCMediaPlayer *)inRefCon;
	SInt16 *audioBuffer = (SInt16 *)ioData->mBuffers[0].mData;
	NSInteger numSamples = ioData->mBuffers[0].mDataByteSize / sizeof(SInt16);
	NSInteger renderedSamples = [mediaPlayer _renderAudioIntoBuffer:audioBuffer numSamples:numSamples];
	if(renderedSamples > numSamples) {
		NSLog(@"WARNING: DCMediaPlayer rendered too many samples! (%i < %i)", renderedSamples, numSamples);
	}
	return noErr;
}


@interface DCMediaPlayer ()
- (NSURL *)_urlForExportingKey:(NSString *)itemKey;
- (void)_setUpAudioUnits;
@property(nonatomic, retain)DCFileProducer *fileProducer;
@property(nonatomic, retain)NSMutableArray *postProcessingEffects;
@property(nonatomic, assign)BOOL isPlaying;
@end

@implementation DCMediaPlayer
@synthesize mediaURL = _mediaURL;
@synthesize isPlaying = _isPlaying;
@synthesize fileProducer = _fileProducer;
@synthesize postProcessingEffects = _postProcessingEffects;

- (id)init {
	if((self = [super init])) {
		self.postProcessingEffects = [NSMutableArray array];
	}
	return self;
}
- (void)dealloc {
	self.mediaURL = nil;
	self.fileProducer = nil;
	self.postProcessingEffects = nil;
	
	[super dealloc];
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
	
	OSStatus startErr = AudioOutputUnitStart(_remoteIOUnit);
	if(startErr) {
		NSLog(@"Couldn't start RIO unit, error: %ld", startErr);
		return;
	}
	
	self.isPlaying = YES;
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
	}
	_isInitialized = NO;
	self.isPlaying = NO;
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
	
	// Set the stream description for our RIO unit's bus 0 input.
	AudioStreamBasicDescription fileStreamDescription = [_fileProducer audioStreamDescription];
	setupErr = AudioUnitSetProperty(_remoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &fileStreamDescription, sizeof(fileStreamDescription));
	NSAssert1(noErr == setupErr, @"Couldn't set ASBD for remote IO unit on input scope / bus 0; error: %i", setupErr);
	
	
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
- (void)setMediaURL:(NSURL *)mediaURL {
	[mediaURL retain];
	[_mediaURL release];
	_mediaURL = mediaURL;
	
	// Re-create our file producer.
	self.fileProducer = [[[DCFileProducer alloc] initWithMediaURL:mediaURL] autorelease];
}


#pragma mark -
- (void)_postProcessSamplesInBuffer:(SInt16 *)buffer numSamples:(NSInteger)numSamples {
	// Pass this sample to each of our post-processors.
	for(DCAudioEffect *effect in self.postProcessingEffects) {
		if(effect.enabled) {
			[effect processSamplesInBuffer:buffer numSamples:numSamples];
		}
	}
}
- (NSInteger)_renderAudioIntoBuffer:(SInt16 *)buffer numSamples:(NSInteger)numSamples {
	// Call our renderer.
	NSInteger numSamplesRendered = [_fileProducer renderAudioIntoBuffer:buffer numSamples:numSamples];
	
	// Do any post-processing.
	[self _postProcessSamplesInBuffer:buffer numSamples:numSamplesRendered];
	
	return numSamplesRendered;
}


#pragma mark -
#pragma Effects
- (void)addPostProcessingEffect:(DCAudioEffect *)effect {
	// Add the effect to our array.
	[self.postProcessingEffects addObject:effect];
	
	// Make sure all the non-destructive effects are first!
	[self.postProcessingEffects sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		DCAudioEffect *e1 = (DCAudioEffect *)obj1;
		DCAudioEffect *e2 = (DCAudioEffect *)obj2;
		if(e1.destructive == e2.destructive) {
			return NSOrderedSame;
		}
		else if(e1.destructive) {
			return NSOrderedDescending;
		}
		return NSOrderedAscending;
	}];
}

@end
