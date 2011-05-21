//
//  DCMediaExporter.h
//  MediaPlayerDemo
//
//  Created by David Cairns on 5/20/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@class DCMediaExporter;
@protocol DCMediaExporterDelegate <NSObject>
- (void)exporterCompleted:(DCMediaExporter *)exporter;
@end

@interface DCMediaExporter : NSObject {
	
}

- (id)initWithMediaItem:(MPMediaItem *)mediaItem exportURL:(NSURL *)exportURL delegate:(id<DCMediaExporterDelegate>)delegate;
- (BOOL)startExporting;

- (NSURL *)exportURL;
@property(nonatomic, assign)id<DCMediaExporterDelegate> delegate;

@end
