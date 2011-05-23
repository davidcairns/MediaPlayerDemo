//
//  MediaPlayerDemoViewController.h
//  MediaPlayerDemo
//
//  Created by David Cairns on 4/22/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import "DCMediaExporter.h"

@interface MediaPlayerDemoViewController : UIViewController <DCMediaExporterDelegate, MPMediaPickerControllerDelegate> {
	
}

@property(nonatomic, retain)IBOutlet UISwitch *effectsSwitch;
- (IBAction)effectsSwitchToggled:(id)sender;

@property(nonatomic, retain)IBOutlet UIActivityIndicatorView *spinner;
@property(nonatomic, retain)IBOutlet UIButton *albumArtButton;
- (IBAction)albumArtButtonTapped:(id)sender;

@property(nonatomic, retain)IBOutlet UILabel *songLabel;
@property(nonatomic, retain)IBOutlet UILabel *albumLabel;
@property(nonatomic, retain)IBOutlet UILabel *artistLabel;

@property(nonatomic, retain)IBOutlet UIButton *playButton;
- (IBAction)playStopButtonTapped:(id)sender;

@end
