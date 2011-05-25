//
//  DCFileProducer.h
//  MediaPlayerDemo
//
//  Created by David Cairns on 5/22/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DCAudioProducer.h"

@interface DCFileProducer : DCAudioProducer {
	AudioSampleType *_audioDataBuffer;
	AudioSampleType *_scratchBuffer;
	
	AudioFileID _audioFile;
}

- (id)initWithMediaURL:(NSURL *)mediaURL;
- (NSURL *)mediaURL;

@end
