//
//  AppDelegate.h
//
//  Copyright © 2016 Alejandro Iván Melo Domínguez
//  All rights reserved.
//  www.penquistas.cl
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UIEvent.h>
#import <UIKit/UIImage.h>

#import "RadioManagerMetadataParser.h"



/*
 IMPORTANT NOTE
 ==============
 
 Remember to set App Transport to allow connections to your streaming URL (if you're not using HTTPS).
 
 Info.plist -> Add Row -> App Transport Security Settings -> ("+" sign) -> Allow Arbitrary Loads -> YES.
 */




#define DEBUG_RADIOMANAGER YES // Enables/disables the log of events (if NO or not defined, nothing will be printed to console).

typedef NS_ENUM(NSInteger, RadioManagerStatus) {
    RadioManagerStatusLoading,  // The stream is loading (connecting, buffering, etc.).
    RadioManagerStatusPlaying,  // The stream is playing.
    RadioManagerStatusStopped,  // The stream is stopped.
    RadioManagerStatusPaused    // The stream is paused.
};





#pragma mark - ==== PROTOCOLS ====

#pragma mark Delegate
// This is the protocol for the delegate object (usually your UIViewController).
// When changing the playback status (see the RadioManagerStatus enumeration),
// the delegate is informed by calling these methods on it.

@protocol RadioManagerDelegate <NSObject>
@optional
- (void)RMLoading;
- (void)RMPlaying;
- (void)RMPaused;
- (void)RMStopped;
- (void)RMMetadataUpdated:(NSDictionary *)metadata;
@end









@interface RadioManager : NSObject





#pragma mark - ==== DELEGATION ====
#pragma mark Properties
@property (weak, nonatomic) id<RadioManagerDelegate> delegate;










#pragma mark - ==== INITIALIZATION ====
#pragma mark Class methods
// Singleton (these methods return a singleton instance, but they won't start playback).
+ (instancetype)sharedManager;
+ (instancetype)sharedManagerWithStreamUrl:(NSString *)streamUrl;

#pragma mark Instance methods
// Create new instances (not singleton ones).
- (instancetype)init;
- (instancetype)initWithStreamUrl:(NSString *)streamUrl;










#pragma mark - ==== URL ====
#pragma mark Properties
// This is the URL of the stream to play.
// To change a streaming URL, simply stop the player, set this new URL and start playing again.
// This "change URL" behavior is implemented in -playStreamUrl:.
@property (strong, nonatomic) NSString *streamUrl;










#pragma mark - ==== PLAYBACK ====
#pragma mark Properties
@property (assign, nonatomic) BOOL pauseStopsPlaying; // The pause button should stop instead of pausing.
@property (assign, nonatomic, readonly) BOOL isPlaying; // The streaming is playing (either loading or actually playing audio).

#pragma mark Instance methods
// These methods control playback.
// -playPause will call -playStop if self.pauseStopsPlaying is set to YES
- (void)play;
- (void)stop;
- (void)pause;

- (void)playPause;
- (void)playStop;

// Changes the playback to a new streaming URL (stops, changes self.streamUrl and starts playing again).
- (void)playStreamUrl:(NSString *)streamUrl;










#pragma mark - ==== PLAYBACK STATUS ====
#pragma mark Properties
@property (assign, nonatomic, readonly) RadioManagerStatus status; // Status of the player, see RadioManagerStatus enumeration.










#pragma mark - ==== METADATA ====
#pragma mark Properties
// An object implementing the RadioManagerMetadataParser.
// It will receive a NSString (the "title" from the metadata from the stream) and this object will parse it.
// Once parsed, it will be delivered to the delegate object with the RMMetadataUpdated: method.
// For instance, you could send a title like song|artist|anotherdata and parse it with this object. Your delegate
// will receive its metadata already converted to a NSDictionary.
// This doesn't parse images: You should get the image you want to show in the delegate. Use "anotherdata" for getting
// that URL and load it asynchronously (for example, using UIImageView+AFNetworking if you use that framework).
// See RadioManagerMetadataParser.h for more details.
@property (strong, nonatomic) id<RadioManagerMetadataParser> metadataParser;

#pragma mark Class methods
// These are helper methods to send metadata to the iOS now playing info center.

// Takes a three-element array with metadata in order: title (NSString), artist (NSString), image (UIImage)
// This creates a dictionary and calls sendMediaInfoWithTitle:andArtist:andImage:
+ (void)sendMediaInfoWithArguments:(NSArray *)arguments;

// Same as above but with a dictionary (keys: title, artist, image)
+ (void)sendMediaInfoWithTitle:(NSString *)title andArtist:(NSString *)artist andImage:(UIImage *)image;

// Clears all the metadata from the iOS now playing info center.
+ (void)clearMediaInfoFromMediaPlayer;




#pragma mark - ==== BACKGROUND AUDIO SESSION / REMOTE CONTROLS ====
#pragma mark Class methods
// Configures the audio session to play in background.
+ (void)enableAudioSession;

// Disables the audio session to play in background. This shouldn't be used
// unless absolutely necesarry, as it's done automatically on app quitting.
+ (void)disableAudioSession;



// Begins the iOS remote controls capture on the app. This should be called from the application:didFinishLaunchingWithOptions:
// method in the App Delegate. It also needs to implement these two methods:
//
// #import "RadioManager.h" // In your .h file or whatever... I personally prefer it in a Prefix Header.
//
// - (void)remoteControlReceivedWithEvent:(UIEvent *)event {
//     [[RadioManager sharedManager] processRemoteControlEvent:event];
// }
//
// - (BOOL) canBecomeFirstResponder {
//     return YES;
// }
+ (void)enableRemoteControls;

#pragma mark Instance methods
// Takes the event for the remote controls. They're passed by the App Delegate with the method above.
- (void)processRemoteControlEvent:(UIEvent *)event;

@end
