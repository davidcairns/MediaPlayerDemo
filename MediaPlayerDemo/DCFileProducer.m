//
//  DCFileProducer.m
//  MediaPlayerDemo
//
//  Created by David Cairns on 5/22/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import "DCFileProducer.h"
#import "DCRingBufferRecord.h"

#define kRingBufferLength (1 << 20) // 1M
#define kScratchBufferLength (64 << 10) // 64K
#define kLowWatermark (16 << 10) // 16K

@interface DCFileProducer ()
@property(nonatomic, retain)NSURL *mediaURL;
@property(nonatomic, readonly)dispatch_queue_t audioBufferAccessQueue;
@property(nonatomic, retain)DCRingBufferRecord *ringBufferRecord;

@property(nonatomic, assign)AudioStreamBasicDescription audioStreamDescription;
@property(nonatomic, assign)UInt64 audioFileSize;
@property(nonatomic, assign)SInt64 audioFileOffset;
@end

@implementation DCFileProducer
@synthesize mediaURL = _mediaURL;
@synthesize audioBufferAccessQueue = _audioBufferAccessQueue;
@synthesize ringBufferRecord = _ringBufferRecord;
@synthesize audioStreamDescription = _audioStreamDescription;
@synthesize audioFileSize = _audioFileSize;
@synthesize audioFileOffset = _audioFileOffset;

- (id)initWithMediaURL:(NSURL *)mediaURL {
	if((self = [super init])) {
		self.mediaURL = mediaURL;
		
		// Create our access queue.
		_audioBufferAccessQueue = dispatch_queue_create("DCAudioBufferAccessQueueLabel", NULL);
		
		// Create our ring buffer record and its backing store.
		self.ringBufferRecord = [[[DCRingBufferRecord alloc] initWithLength:kRingBufferLength] autorelease];
		_audioDataBuffer = (AudioSampleType *)malloc(kRingBufferLength * sizeof(SInt16));
		memset(_audioDataBuffer, 0, kRingBufferLength * sizeof(SInt16));
		
		// Set up our scratch buffer.
		_scratchBuffer = (AudioSampleType *)malloc(kScratchBufferLength * sizeof(SInt16));
		memset(_scratchBuffer, 0, kScratchBufferLength * sizeof(SInt16));
		
		// Get an Audio File representation for the song.
		OSStatus err = AudioFileOpenURL((CFURLRef)self.mediaURL, kAudioFileReadPermission, 0, &_audioFile);
		NSAssert(noErr == err, @"Couldn't open audio file");
		
		// Read in the entire audio file (NOT recommended). It would be better to use a ring buffer: thread or timer fills, render callback drains.
		UInt32 audioDataByteCountSize = sizeof(_audioFileSize);
		err = AudioFileGetProperty(_audioFile, kAudioFilePropertyAudioDataByteCount, &audioDataByteCountSize, &_audioFileSize);
		NSAssert(noErr == err, @"Couldn't get size property");
		
		// Get the audio file's stream description.
		UInt32 audioStreamDescriptionSize = sizeof(_audioStreamDescription);
		err = AudioFileGetProperty(_audioFile, kAudioFilePropertyDataFormat, &audioStreamDescriptionSize, &_audioStreamDescription);
		NSAssert1(noErr == err, @"ERROR: Couldn't get file's Audio Stream Basic Description; error: ", err);
	}
	return self;
}
- (void)dealloc {
	self.mediaURL = nil;
	dispatch_release(self.audioBufferAccessQueue);
	self.ringBufferRecord = nil;
	
	free(_audioDataBuffer);
	free(_scratchBuffer);
	
	[super dealloc];
}

#pragma mark -
- (void)prepare {
	
}

- (NSInteger)renderAudioIntoBuffer:(SInt16 *)buffer numSamples:(NSInteger)numSamples {
	__block SInt16 *bufferPointer = buffer;
	__block NSInteger samplesRemaining = numSamples;
	__block NSInteger samplesRendered = 0;
	
	dispatch_sync(self.audioBufferAccessQueue, ^ {
		while(samplesRemaining > 0) {
			// Determine how many samples we can read.
			int samplesAvailable = MIN(samplesRemaining, [self.ringBufferRecord fillCountContiguous]);
			if(0 == samplesAvailable) {
				break;
			}
			
			// Get the pointer to read from.
			SInt16 *sourceBuffer = _audioDataBuffer + self.ringBufferRecord.tail;
			
			// Do the actual copy.
			memcpy(bufferPointer, sourceBuffer, samplesAvailable * sizeof(SInt16));
			
			// Advance our pointers.
			bufferPointer += samplesAvailable;
			samplesRemaining -= samplesAvailable;
			samplesRendered += samplesAvailable;
			[self.ringBufferRecord consumeAmount:samplesAvailable];
		}
		
		// If the current fill is below the low watermark, schedule a production block.
		if(self.ringBufferRecord.fillCount < kLowWatermark) {
			dispatch_async(self.audioBufferAccessQueue, ^ {
				// Make sure we're not going to overflow our ring buffer.
				int numEntriesOpenForWriting = self.ringBufferRecord.space;
				
				// Make sure the file has been set up.
				if(!_audioFile) {
					return;
				}
				
				// Read data from the audio file into our temporary (scratch) buffer.
				UInt32 numItemsToRead = MIN(kScratchBufferLength, numEntriesOpenForWriting);
				UInt32 bytesRead = MIN(numItemsToRead * sizeof(SInt16), self.audioFileSize - self.audioFileOffset);
				OSStatus err = AudioFileReadBytes(_audioFile, false, self.audioFileOffset, &bytesRead, _scratchBuffer);
				if(err) {
					NSLog(@"ERROR: Failed to read from file, err: %ld", err);
//					[self stop];
					return;
				}
				
				// Advance our read offset.
				self.audioFileOffset += bytesRead;
				
				// Check to see if we should loop (continuing playing from the beginning of the file).
				if(self.audioFileOffset >= self.audioFileSize) {
					self.audioFileOffset = 0;
				}
				
				// Make sure our buffers still exist.
				if(_ringBufferRecord && _audioDataBuffer && _scratchBuffer) {
					int samplesRead = bytesRead / sizeof(SInt16);
					// Copy samples from our scratch buffer into our ring buffer's backing store.
					[self.ringBufferRecord copyNumElements:samplesRead ofSize:sizeof(SInt16) fromBuffer:_scratchBuffer toBuffer:_audioDataBuffer];
				}
			});
		}
		
	});
	
	return samplesRendered;
}

@end
