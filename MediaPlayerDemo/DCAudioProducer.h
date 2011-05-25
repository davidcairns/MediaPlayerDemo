//
//  DCAudioProducer.h
//  MediaPlayerDemo
//
//  Created by David Cairns on 5/24/11.
//  Copyright 2011 ngmoco:). All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface DCAudioProducer : NSObject {
    
}

@property(nonatomic, assign)AudioStreamBasicDescription audioStreamDescription;

- (NSInteger)renderAudioIntoBuffer:(SInt16 *)buffer numSamples:(NSInteger)numSamples;

@end
