//
//  DCFileProducer.h
//  MediaPlayerDemo
//
//  Created by David Cairns on 5/22/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface DCFileProducer : NSObject {
	AudioSampleType *_audioDataBuffer;
	AudioSampleType *_scratchBuffer;
	
	AudioFileID _audioFile;
	
	NSTimer *_producerTimer;
}

- (id)initWithMediaURL:(NSURL *)mediaURL;

// Begins production (if needed).
- (void)prepare;

- (NSInteger)renderAudioIntoBuffer:(SInt16 *)buffer numSamples:(NSInteger)numSamples;

- (AudioStreamBasicDescription)audioStreamDescription;
- (NSURL *)mediaURL;

@end
