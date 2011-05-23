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

@interface DCMediaPlayer : NSObject {
	BOOL _isPlaying;
	
	BOOL _isInitialized;
	AudioUnit _remoteIOUnit;
}

@property(nonatomic, retain)NSURL *mediaURL;

- (void)play;
- (void)stop;

- (BOOL)isPlaying;

// Effects
- (void)addPostProcessingEffect:(DCAudioEffect *)effect;

@end
