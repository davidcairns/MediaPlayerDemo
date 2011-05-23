//
//  DCAudioEffectLowPassFilter.h
//  MediaPlayerDemo
//
//  Created by David Cairns on 5/22/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DCAudioEffect.h"

@interface DCAudioEffectLowPassFilter : DCAudioEffect {
	float _xv[3];
	float _yv[3];
}

@end
