//
//  DCAudioEffect.h
//  MediaPlayerDemo
//
//  Created by David Cairns on 5/22/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface DCAudioEffect : NSObject {
    
}

@property(nonatomic, assign)BOOL enabled;
@property(nonatomic, assign)BOOL destructive;

- (void)processSamplesInBuffer:(SInt16 *)buffer numSamples:(NSInteger)numSamples;

@end
