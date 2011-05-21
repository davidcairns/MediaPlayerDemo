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
@property(nonatomic, retain)DCMediaExporter *mediaExporter;
@property(nonatomic, retain)DCMediaPlayer *mediaPlayer;
@property(nonatomic, retain)MPMediaPickerController *mediaPickerController;
@property(nonatomic, retain)MPMediaItem *selectedMediaItem;
- (void)_updateFields;
- (NSURL *)_exportURLForMediaItem:(MPMediaItem *)mediaItem;
@end

@implementation MediaPlayerDemoViewController
@synthesize mediaPlayer = _mediaPlayer;
@synthesize mediaPickerController = _mediaPickerController;
@synthesize mediaExporter = _mediaExporter;
@synthesize selectedMediaItem = _selectedMediaItem;
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
	self.mediaExporter.delegate = nil;
	self.mediaExporter = nil;
	self.mediaPlayer = nil;
	_mediaPickerController.delegate = nil;
	self.selectedMediaItem = nil;
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
	
	self.playButton.hidden = (nil == self.selectedMediaItem);
}


#pragma mark -
#pragma mark KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if([keyPath isEqualToString:@"isPlaying"]) {
		self.playButton.hidden = (nil == self.selectedMediaItem);
		[self.playButton setTitle:(self.mediaPlayer.isPlaying ? @"Stop" : @"Play") forState:UIControlStateNormal];
	}
}

#pragma mark -
#pragma DCMediaExporterDelegate
- (void)exporterCompleted:(DCMediaExporter *)exporter {
	// Pass the exported URL to our player.
	self.mediaPlayer.mediaURL = exporter.exportURL;
	
	[[UIApplication sharedApplication] endIgnoringInteractionEvents];
	[self.spinner stopAnimating];
	[self.mediaPlayer play];
}

#pragma mark -
#pragma MPMediaPickerControllerDelegate
- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
	// Hide our media picker.
	[self dismissModalViewControllerAnimated:YES];
}
- (void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
	// Grab the selected media item's asset URL.
	
	// Create a new media exporter with the media item's asset URL.
	self.selectedMediaItem = [mediaItemCollection.items objectAtIndex:0];
	self.mediaExporter = [[[DCMediaExporter alloc] initWithMediaItem:self.selectedMediaItem exportURL:[self _exportURLForMediaItem:self.selectedMediaItem] delegate:self] autorelease];
	if([self.mediaExporter startExporting]) {
		// Make the UI reflect the fact that we're exporting.
		[[UIApplication sharedApplication] beginIgnoringInteractionEvents];
		[self.spinner startAnimating];
	}
	else {
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
	self.playButton.hidden = (nil == self.selectedMediaItem);
	
	// Get the artist name.
	self.artistLabel.text = [self.selectedMediaItem valueForProperty:MPMediaItemPropertyAlbumArtist];
	if(![self.artistLabel.text length]) {
		// Try artist name instead of album artist.
		self.artistLabel.text = [self.selectedMediaItem valueForProperty:MPMediaItemPropertyArtist];
	}
	
	// Get the song name.
	self.songLabel.text = [[self.selectedMediaItem valueForProperty:MPMediaItemPropertyTitle] uppercaseString];
	
	// Get the album artwork.
	MPMediaItemArtwork *albumArtwork = [self.selectedMediaItem valueForProperty:MPMediaItemPropertyArtwork];
	UIImage *albumImage = [albumArtwork imageWithSize:albumArtwork.imageCropRect.size];
	if(!albumImage) {
		albumImage = [UIImage imageNamed:@"no-art.png"];
	}
	[self.albumArtButton setBackgroundImage:albumImage forState:UIControlStateNormal];
	
	// Change our song selection button's background image.
	UIImage *selectSongImage = self.selectedMediaItem ? [UIImage imageNamed:@"album-overlay-button-image.png"] : [UIImage imageNamed:@"select-song-button-background.png"];
	[self.albumArtButton setBackgroundImage:selectSongImage forState:UIControlStateNormal];
}

- (NSURL *)_exportURLForMediaItem:(MPMediaItem *)mediaItem {
	// Get the file path.
	NSString *documentsDirectoryPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
	NSString *exportFilePath = [documentsDirectoryPath stringByAppendingPathComponent:@"auto-old.caf"];
	
	// Make sure the file path we want to export to doesn't already exist.
	if([[NSFileManager defaultManager] fileExistsAtPath:exportFilePath]) {
		NSError *error = nil;
		if(![[NSFileManager defaultManager] removeItemAtPath:exportFilePath error:&error]) {
			NSLog(@"Failed to clear out export file, with error: %@", error);
		}
	}
	
	return [NSURL fileURLWithPath:exportFilePath];
}

- (void)setMediaExporter:(DCMediaExporter *)mediaExporter {
	[mediaExporter retain];
	_mediaExporter.delegate = nil;
	[_mediaExporter release];
	_mediaExporter = mediaExporter;
}

@end
