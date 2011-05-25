//
//  DCMediaPlayer.h
//  MediaPlayerDemo
//
//  Created by David Cairns on 4/5/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "DCAudioEffect.h"
#import "DCAudioProducer.h"

@interface DCMediaPlayer : NSObject {
	AudioUnit _remoteIOUnit;
}

@property(nonatomic, retain)DCAudioProducer *audioProducer;

- (void)play;
- (void)stop;

- (BOOL)isPlaying;

// Effects
- (void)addPostProcessingEffect:(DCAudioEffect *)effect;

@end
