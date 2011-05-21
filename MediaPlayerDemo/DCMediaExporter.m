//
//  DCMediaExporter.m
//  MediaPlayerDemo
//
//  Created by David Cairns on 5/20/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import "DCMediaExporter.h"
#import <AVFoundation/AVFoundation.h>

@interface DCMediaExporter ()
@property(nonatomic, retain)MPMediaItem *mediaItem;
@property(nonatomic, retain)NSURL *exportURL;
- (NSDictionary *)_writerInputOutputSettings;
@end

@implementation DCMediaExporter
@synthesize mediaItem = _mediaItem;
@synthesize exportURL = _exportURL;
@synthesize delegate = _delegate;

- (id)initWithMediaItem:(MPMediaItem *)mediaItem exportURL:(NSURL *)exportURL delegate:(id<DCMediaExporterDelegate>)delegate {
	if((self = [super init])) {
		self.mediaItem = mediaItem;
		self.exportURL = exportURL;
		self.delegate = delegate;
	}
	return self;
}
- (void)dealloc {
	self.mediaItem = nil;
	self.exportURL = nil;
	[super dealloc];
}


- (BOOL)startExporting {
	/*
	 * This code was appropriated from:
	 * http://www.subfurther.com/blog/2010/12/13/from-ipod-library-to-pcm-samples-in-far-fewer-steps-than-were-previously-necessary/
	 * (Thanks, Chris Adamson!)
	 */
	
	// First get the asset's URL.
	NSURL *assetURL = [self.mediaItem valueForProperty:MPMediaItemPropertyAssetURL];
	if(!assetURL) {
		NSLog(@"Failed to get asset url for item: %@", self.mediaItem);
		return NO;
	}
	
	// Get the AVAsset for this song.
	AVURLAsset *asset = [AVURLAsset URLAssetWithURL:assetURL options:nil];
	if(!asset) {
		NSLog(@"Failed to get asset for url: %@", assetURL);
		return NO;
	}
	
	// Create an AVAssetReader.
	NSError *error = nil;
	AVAssetReader *assetReader = [[AVAssetReader assetReaderWithAsset:asset error:&error] retain];
	if(!assetReader || error) {
		NSLog(@"Failed creating asset reader, with error: %@", error);
		return NO;
	}
	
	// Create an output for our reader.
	AVAssetReaderOutput *assetReaderOutput = [[AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:asset.tracks audioSettings:nil] retain];
	
	// Add the output to our asset reader.
	if(![assetReader canAddOutput:assetReaderOutput]) {
		NSLog(@"Failure: cannot add output to asset reader.");
		return NO;
	}
	[assetReader addOutput:assetReaderOutput];
	
	// Create an asset writer for our export URL.
	AVAssetWriter *assetWriter = [[AVAssetWriter assetWriterWithURL:self.exportURL fileType:AVFileTypeCoreAudioFormat error:&error] retain];
	if(!assetWriter || error) {
		NSLog(@"Failed to create asset writer for URL: %@, error: %@", self.exportURL, error);
		return NO;
	}
	
	// Set up our asset writer input, to represent the file we're going to be writing into.
	AVAssetWriterInput *assetWriterInput = [[AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:[self _writerInputOutputSettings]] retain];
	assetWriterInput.expectsMediaDataInRealTime = NO;
	
	// Add the input to our asset writer.
	if(![assetWriter canAddInput:assetWriterInput]) {
		NSLog(@"Failure: cannot add asset writer input.");
		return NO;
	}
	[assetWriter addInput:assetWriterInput];
	
	// Start our reader and writer.
	if(![assetReader startReading]) {
		NSLog(@"Failed to start reading asset, with error: %@", assetReader.error);
		return NO;
	}
	if(![assetWriter startWriting]) {
		NSLog(@"Failed to start writing asset, with error: %@", assetWriter.error);
		return NO;
	}
	
	// Configure our asset writer's start time.
	AVAssetTrack *soundTrack = [asset.tracks objectAtIndex:0];
	[assetWriter startSessionAtSourceTime:CMTimeMake(0, soundTrack.naturalTimeScale)];
	
	// Specify what actually happens during the reading / writing session.
	dispatch_queue_t mediaInputQueue = dispatch_queue_create("mediaInputQueue", NULL);
	[assetWriterInput requestMediaDataWhenReadyOnQueue:mediaInputQueue usingBlock:^ {
		while(assetWriterInput.readyForMoreMediaData) {
			// Get the next sample buffer from the asset reader.
			CMSampleBufferRef bufferRef = [assetReaderOutput copyNextSampleBuffer];
			
			// If there's no next buffer, then we're done!
			if(!bufferRef) {
				[assetWriterInput markAsFinished];
				[assetWriter finishWriting];
				[assetReader cancelReading];
				
				// Clean up the objects we'd been holding on to and leave the cycle.
				[assetReader release];
				[assetReaderOutput release];
				[assetWriter release];
				[assetWriterInput release];
				
				// Tell our delegate that we're done exporting.
				dispatch_sync(dispatch_get_main_queue(), ^{
					[self.delegate exporterCompleted:self];
				});
				break;
			}
			
			// Otherwise, append the buffer and keep looping.
			[assetWriterInput appendSampleBuffer:bufferRef];
		}
	}];
	
	return YES;
}

#pragma mark -
- (NSDictionary *)_writerInputOutputSettings {
	// Set up the audio channel layout description for our asset writer.
	AudioChannelLayout audioChannelLayout;
	memset(&audioChannelLayout, 0, sizeof(AudioChannelLayout));
	audioChannelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey, 
			[NSNumber numberWithFloat:44100.0f], AVSampleRateKey, 
			[NSNumber numberWithInt:2], AVNumberOfChannelsKey, 
			[NSData dataWithBytes:&audioChannelLayout length:sizeof(audioChannelLayout)], AVChannelLayoutKey, 
			[NSNumber numberWithInt:16], AVLinearPCMBitDepthKey, 
			[NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved, 
			[NSNumber numberWithBool:NO], AVLinearPCMIsFloatKey, 
			[NSNumber numberWithBool:NO], AVLinearPCMIsBigEndianKey, 
			nil];
}

@end
