//
//  MediaPlayerDemoViewController.m
//  MediaPlayerDemo
//
//  Created by David Cairns on 4/22/11.
//  Copyright 2011 David Cairns. All rights reserved.
//

#import "MediaPlayerDemoViewController.h"
#import "DCMediaPlayer.h"

@interface MediaPlayerDemoViewController ()
@property(nonatomic, retain)DCMediaPlayer *mediaPlayer;
@property(nonatomic, retain)MPMediaPickerController *mediaPickerController;
- (void)_updateFields;
@end

@implementation MediaPlayerDemoViewController
@synthesize mediaPlayer = _mediaPlayer;
@synthesize mediaPickerController = _mediaPickerController;
@synthesize effectsSwitch = _effectsSwitch;
@synthesize spinner = _spinner;
@synthesize albumArtButton = _albumArtButton;
@synthesize songLabel = _songLabel;
@synthesize albumLabel = _albumLabel;
@synthesize artistLabel = _artistLabel;
@synthesize playButton = _playButton;

- (void)_commonInit {
	// Set up our media picker controller.
	_mediaPickerController = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeAnyAudio];
	_mediaPickerController.delegate = self;
	
	// Set up our media player.
	_mediaPlayer = [[DCMediaPlayer alloc] init];
	
	// Observe changes in the media player's activity.
	[_mediaPlayer addObserver:self forKeyPath:@"isImporting" options:NSKeyValueObservingOptionNew context:NULL];
	[_mediaPlayer addObserver:self forKeyPath:@"isPlaying" options:NSKeyValueObservingOptionNew context:NULL];
}
- (id)init {
	if([super init]) {
		[self _commonInit];
	}
	return self;
}
- (id)initWithCoder:(NSCoder *)aDecoder {
	if([super initWithCoder:aDecoder]) {
		[self _commonInit];
	}
	return self;
}
- (void)dealloc {
	[_mediaPlayer release];
	_mediaPickerController.delegate = nil;
	[_mediaPickerController release];
	[_effectsSwitch release];
	[_spinner release];
	[_albumArtButton release];
	[_songLabel release];
	[_albumLabel release];
	[_artistLabel release];
	[_playButton release];
	[_alertView release];
	[super dealloc];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	
	self.effectsSwitch = nil;
	self.spinner = nil;
	self.albumArtButton = nil;
	self.songLabel = nil;
	self.albumLabel = nil;
	self.artistLabel = nil;
	self.playButton = nil;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.playButton.hidden = (nil == self.mediaPlayer.item);
}


#pragma mark -
#pragma mark KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if([keyPath isEqualToString:@"isImporting"]) {
		if(self.mediaPlayer.isImporting) {
			[[UIApplication sharedApplication] beginIgnoringInteractionEvents];
			[self.spinner startAnimating];
			NSLog(@"started spinner: %@", self.spinner);
		}
		else {
			[[UIApplication sharedApplication] endIgnoringInteractionEvents];
			[self.spinner stopAnimating];
			[self.mediaPlayer play];
		}
	}
	else if([keyPath isEqualToString:@"isPlaying"]) {
		self.playButton.hidden = (nil == self.mediaPlayer.item);
		[self.playButton setTitle:(self.mediaPlayer.isPlaying ? @"Stop" : @"Play") forState:UIControlStateNormal];
	}
}

#pragma mark -
#pragma MPMediaPickerControllerDelegate
- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
	// Hide our media picker.
	[self dismissModalViewControllerAnimated:YES];
}
- (void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
	// Grab the selected media item and pass it to our media player.
	if(![self.mediaPlayer prepareMediaItem:[mediaItemCollection.items objectAtIndex:0] forKey:@"auto-old"]) {
		// If something went wrong, tell the user to select a different song.
		[_alertView release];
		_alertView = [[UIAlertView alloc] initWithTitle:@"Oh no!" message:@"Sorry, we can't copy that track. Please select another." delegate:self cancelButtonTitle:@"D'oh!" otherButtonTitles:nil];
		[_alertView show];
	}
	
	// Change our song selection button's background image.
	[self.albumArtButton setBackgroundImage:[UIImage imageNamed:@"album-overlay-button-image.png"] forState:UIControlStateNormal];
	
	// Update our view.
	[self _updateFields];
	
	// Hide our media picker.
	[self dismissModalViewControllerAnimated:YES];
}


#pragma mark -
#pragma mark UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	[_alertView release];
	_alertView = nil;
}


#pragma mark -
- (IBAction)albumArtButtonTapped:(id)sender {
	// Display our song-selector modal.
	[self presentModalViewController:self.mediaPickerController animated:YES];
}
- (IBAction)effectsSwitchToggled:(id)sender {
	self.mediaPlayer.useEffects = self.effectsSwitch.on;
}

- (IBAction)playStopButtonTapped:(id)sender {
	if(self.mediaPlayer.isPlaying) {
		[self.mediaPlayer stop];
	}
	else {
		[self.mediaPlayer play];
	}
}


- (void)_updateFields {
	MPMediaItem *item = self.mediaPlayer.item;
	
	self.playButton.hidden = (nil == item);
	
	// Get the artist name.
	self.artistLabel.text = [item valueForProperty:MPMediaItemPropertyAlbumArtist];
	if(![self.artistLabel.text length]) {
		// Try artist name instead of album artist.
		self.artistLabel.text = [item valueForProperty:MPMediaItemPropertyArtist];
	}
	
	// Get the song name.
	self.songLabel.text = [[item valueForProperty:MPMediaItemPropertyTitle] uppercaseString];
	
	// Get the album artwork.
	MPMediaItemArtwork *albumArtwork = [item valueForProperty:MPMediaItemPropertyArtwork];
	UIImage *albumImage = [albumArtwork imageWithSize:albumArtwork.imageCropRect.size];
	if(!albumImage) {
		albumImage = [UIImage imageNamed:@"no-art.png"];
	}
	[self.albumArtButton setBackgroundImage:albumImage forState:UIControlStateNormal];
	
	// Change our song selection button's background image.
	UIImage *selectSongImage = item ? [UIImage imageNamed:@"album-overlay-button-image.png"] : [UIImage imageNamed:@"select-song-button-background.png"];
	[self.albumArtButton setBackgroundImage:selectSongImage forState:UIControlStateNormal];
}

@end
