//
//  AppDelegate.h
//
//  Copyright © 2016 Alejandro Iván Melo Domínguez
//  All rights reserved.
//  www.penquistas.cl
//

#import "RadioManager.h"
#import <MediaPlayer/MediaPlayer.h>

// We use the Reachability code sample provided by Apple Inc.
// Available at: https://developer.apple.com/library/ios/samplecode/Reachability
// We include it in this project (inside the Reachability folder), but I don't own that code.
// Check their LICENSE.txt in that website (or the REACHABILITY_LICENSE.txt file) for licensing terms.
#import "Reachability.h"


// Wrapper for NSLog. DEBUG_RADIOMANAGER should be defined to YES if you want to log events to the console.
#ifndef LOG_RADIOMANAGER
#ifdef DEBUG_RADIOMANAGER
#if DEBUG_RADIOMANAGER == YES
#define LOG_RADIOMANAGER(text, ...) \
NSLog(text, ##__VA_ARGS__);
#else
#define LOG_RADIOMANAGER(text, ...)\
nil
#endif
#else
#define LOG_RADIOMANAGER(text, ...)\
nil
#endif
#endif

static RadioManager *__radioManagerSingleton;


#pragma mark - Private interface
@interface RadioManager ()

#pragma mark Properties
@property (strong, nonatomic) AVPlayerItem *playerItem;
@property (strong, nonatomic) AVPlayer *player;
@property (assign, nonatomic) BOOL playWhenReady;
@property (assign, nonatomic) BOOL continueAfterReachabilityChange;

@property (strong, nonatomic) NSTimer *currentTimeUpdaterTimer;

#pragma mark Instance methods
// These are merely helpers for messaging the delegate.
// They check if the delegate actually responds to a selector and then messages it.

// Checks if the delegate responds to a selector and messages it if it does.
- (void)delegate_callMethod:(SEL)method;

// Checks if the delegate responds to a selector and messages it if it does with an object as a parameter.
- (void)delegate_callMethod:(SEL)method withObject:(id)object;

@end


@implementation RadioManager {
    Reachability *internetReachability;
}










#pragma mark - ==== INITIALIZATION ====
#pragma mark Class methods

+ (instancetype)sharedManager {
    LOG_RADIOMANAGER(@"[RadioManager] +sharedManager");
    
    @synchronized( self ) {
        if ( ! __radioManagerSingleton ) {
            __radioManagerSingleton = [[self alloc] init];
        }

        return __radioManagerSingleton;
    }
}


+ (instancetype) sharedManagerWithStreamUrl:(NSString *)streamUrl {
    LOG_RADIOMANAGER(@"[RadioManager] +sharedManagerWithStreamUrl: %@", streamUrl);
    
    __radioManagerSingleton = [self sharedManager];
    
    if ( streamUrl ) {
        __radioManagerSingleton.streamUrl = streamUrl;
    }
    
    return __radioManagerSingleton;
}




#pragma mark Instance methods

- (instancetype)init {
    LOG_RADIOMANAGER(@"[RadioManager] -init");

    if ( self = [super init] ) {
        self.player = self.player ?: [[AVPlayer alloc] init];
        _status     = RadioManagerStatusStopped; // Initial status.
        
        [self setupReachability];
    }
    
    return self;
}

- (instancetype)initWithStreamUrl:(NSString *)streamUrl {
    LOG_RADIOMANAGER(@"[RadioManager] -initWithStreamUrl: %@", streamUrl);
    
    if ( self = [self init] ) { // We use the "init" above (note: it's called on self, not super)
        if ( streamUrl ) {
            self.streamUrl = streamUrl;
        }
    }
    
    return self;
}

- (void)dealloc {
    LOG_RADIOMANAGER(@"[RadioManager] -dealloc");
    // Do cleanup...
    [[NSNotificationCenter defaultCenter] removeObserver:self]; // Just in case.
    
    // Cleanup for AVPlayer. The KVO cleanup is performed on their setters overrides.
    self.player = nil;
    self.playerItem = nil;
}










#pragma mark - ==== CONFIGURATION ====
#pragma mark Media player

- (void)setupPlayer { // First setup/reset self.player
    if ( ! self.player ) {
        LOG_RADIOMANAGER(@"[RadioManager] -setupPlayer (The player has not been instantiated.)");
        return;
    }
    if ( ! self.streamUrl ) {
        LOG_RADIOMANAGER(@"[RadioManager] -setupPlayer (The streamUrl property doesn't have an URL defined.)");
        return;
    }
    
    LOG_RADIOMANAGER(@"[RadioManager] -setupPlayer");
    
    // As this is setup player (or reset), we first stop the player if it's playing
    if ( self.player.currentItem && ! self.player.error && self.player.rate != 0 ) {
        // The player is playing, simulate a "stop" using seek & pause
        
        [self.player seekToTime:CMTimeMake(0, 1)]; // Seeks to initial time
        [self.player pause]; // Pause the player.
    }
    
    // Change the current item of the player
    NSURL *contentUrl = [NSURL URLWithString:self.streamUrl];
    if ( contentUrl ) {
        self.playerItem = [AVPlayerItem playerItemWithURL:contentUrl];
        
        if ( self.playerItem ) {
            [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
        }
        else {
            LOG_RADIOMANAGER(@"[RadioManager] -setupPlayer (%@)", @"Can't initialize an AVPlayerItem.");
            return;
        }
    }
}










#pragma mark - ==== PLAYBACK ====
#pragma mark Instance methods

- (void)play {
    if ( self.player.rate != 0 && ( self.status == RadioManagerStatusLoading || self.status == RadioManagerStatusPlaying ) ) {
        LOG_RADIOMANAGER(@"[RadioManager] -play (The player is already playing.)");
        return;
    }
    
    if ( ! self.streamUrl ) {
        LOG_RADIOMANAGER(@"[RadioManager] - play (The player doesn't have a streamUrl defined.)");
        _status = RadioManagerStatusStopped;
        [self delegate_callMethod:@selector(RMStopped)];
        return;
    }
    
    LOG_RADIOMANAGER(@"[RadioManager] -play");
    
    if ( self.status == RadioManagerStatusStopped ) { // If the radio is stopped, a new AVPlayer instance should be created to play.
        _status = RadioManagerStatusLoading; // When doing this, the status is "loading".
        [self setupPlayer];
        
        if ( self.player.status == AVPlayerStatusReadyToPlay ) { // Inform the delegate of the "loading" status when appropiate.
            [self delegate_callMethod:@selector(RMLoading)];
        }
    }
    else if ( self.status == RadioManagerStatusPaused ) { // If the radio is paused, we simply continue the playback.
        _status = RadioManagerStatusPlaying; // At this point, we already have some data buffered, so the playback continues instantly.
        _hasPlayedBefore = YES;
        
        if ( self.player.status == AVPlayerStatusReadyToPlay ) { // Inform the delegate of the "playing" status when appropiate.
            [self delegate_callMethod:@selector(RMPlaying)];
        }
    }

    _isPlaying = YES;
    [self.player play]; // Tell the AVPlayer instance to play the currently configured AVPlayerItem (in -setupPlayer)
}

- (void)stop {
    if ( self.status == RadioManagerStatusStopped ) {
        LOG_RADIOMANAGER(@"[RadioManager] -stop (The player is already stopped.)");
        return;
    }
    
    LOG_RADIOMANAGER(@"[RadioManager] -stop");
    
    _isPlaying = NO;
    _status = RadioManagerStatusStopped;
    
    // Simulation of the "stop" by seeking to the initial time and then pausing the playback.
    [self.player seekToTime:CMTimeMake(0, 1)];
    [self.player pause];
}

- (void)pause {
    // If the player is paused or stopped, we can't "pause" it again.
    if ( ( self.status == RadioManagerStatusPaused || self.status == RadioManagerStatusStopped ) && self.player.rate == 0 ) {
        LOG_RADIOMANAGER(@"[RadioManager] -pause (The player is already paused or stopped.)");
        return;
    }
    
    if ( self.pauseStopsPlaying ) { // If self.pauseStopsPlaying is YES, then we call -stop instead of actually pausing the playback.
        LOG_RADIOMANAGER(@"[RadioManager] -pause (pauseStopsPlaying is YES, calling -stop)");
        [self stop];
    }
    else {
        LOG_RADIOMANAGER(@"[RadioManager] -pause");
        
        [self.player pause];
        _isPlaying = NO;
        _status = RadioManagerStatusPaused;
    }
}

- (void)playPause {
    LOG_RADIOMANAGER(@"[RadioManager] -playPause");
    
    // If we're stopped or paused, start the playback.
    if ( self.status == RadioManagerStatusPaused || self.status == RadioManagerStatusStopped ) {
        [self play];
    }
    else { // Otherside, pause it.
        [self pause]; // -pause checks for self.pauseStopsPlaying, so we simply call it.
    }
}

- (void)playStop {
    LOG_RADIOMANAGER(@"[RadioManager] -playStop");
    
    // If we're stopped or paused, start the playback.
    if ( self.status == RadioManagerStatusPaused || self.status == RadioManagerStatusStopped ) {
        [self play];
    }
    else {
        [self stop];
    }
}

// This changes the stream URL to a new one specified and starts playing that URL.
- (void)playStreamUrl:(NSString *)streamUrl {
    if ( ! streamUrl || streamUrl.length == 0 ) {
        LOG_RADIOMANAGER(@"[RadioManager] -playStreamUrl: (The stream URL can't be nil.)");
        return;
    }
    
    LOG_RADIOMANAGER(@"[RadioManager] -playStreamUrl: %@", streamUrl);
    
    [self stop];
    [self setStreamUrl:streamUrl];
    [self play];
}











#pragma mark - ==== PLAYBACK STATUS ====
#pragma mark Instance methods

// Handler for KVOs
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if ( object == self.player ) { // KVO on AVPlayer
        
        if ( [keyPath isEqualToString:@"status"] ) { // AVPlayer status
            if ( self.player.status == AVPlayerStatusFailed ) {
                LOG_RADIOMANAGER(@"[RadioManager] AVPlayer failed");
            }
            
            else if ( self.player.status == AVPlayerStatusReadyToPlay ) {
                LOG_RADIOMANAGER(@"[RadioManager] AVPlayer ready to play");
                [self.player play];
            }
            
            else if ( self.player.status == AVPlayerStatusUnknown ) {
                LOG_RADIOMANAGER(@"[RadioManager] AVPlayer unknown");
                _status = RadioManagerStatusStopped; // Unknown error, so we stop the playback.
            }
        }
        
        else if ( [keyPath isEqualToString:@"rate"] ) { // AVPlayer rate
            if ( self.player.rate != 0 ) {
                // Playing
                if ( self.player.status != AVPlayerStatusReadyToPlay ) {
                    // If rate != 0 but the status is not "ready to play", we assume it's "loading".
                    
                    LOG_RADIOMANAGER(@"[RadioManager] RATE = %f (Loading.)", self.player.rate);
                    
                    _status = RadioManagerStatusLoading;
                    [self delegate_callMethod:@selector(RMLoading)];
                }
            }
            else {
                // Inform what self.status has (either stopped or paused) and tell the delegate.
                if ( self.status == RadioManagerStatusStopped ) {
                    LOG_RADIOMANAGER(@"[RadioManager] RATE = 0 (Stopped.)");
                    [self delegate_callMethod:@selector(RMStopped)];
                }
                else {
                    LOG_RADIOMANAGER(@"[RadioManager] RATE = 0 (Paused.)");
                    [self delegate_callMethod:@selector(RMPaused)];
                }
            }
        }
        
    }
    
    else if ( object == self.playerItem ) { // KVO on AVPlayerItem
        
        if ( [keyPath isEqualToString:@"status"] ) { // AVPlayerItem status
            
            if ( self.playerItem.status == AVPlayerItemStatusFailed ) {
                LOG_RADIOMANAGER(@"[RadioManager] AVPlayerItem failed");
                _status = RadioManagerStatusStopped;
            }
            
            else if ( self.playerItem.status == AVPlayerItemStatusReadyToPlay ) {
                LOG_RADIOMANAGER(@"[RadioManager] AVPlayerItem ready to play");
                
                if ( self.player.rate != 0 ) {
                    // Playing
                    _status = RadioManagerStatusPlaying;
                    _hasPlayedBefore = YES;
                    [self delegate_callMethod:@selector(RMPlaying)];
                }
            }
            
            else if ( self.playerItem.status == AVPlayerItemStatusUnknown ) {
                LOG_RADIOMANAGER(@"[RadioManager] AVPlayerItem unknown");
                _status = RadioManagerStatusStopped; // AVPlayerItem status unknown, so we assume playback is stopped.
            }
        }
        
        
        if ( [keyPath isEqualToString:@"timedMetadata"] ) { // AVPlayerItem has received metadata
            NSArray *metadata       = self.playerItem.timedMetadata;
            AVMetadataItem *item    = [metadata firstObject];
            NSString *metadataStr   = (NSString *) item.value;

            NSDictionary *parsedMetadata = nil;
            if ( self.metadataParser ) {
                // We parse the metadata on the parser given by the UIViewController
                parsedMetadata = [self.metadataParser dictionaryFromMetadata:metadataStr];
            }
            else {
                // Or... we give [NSNull null] and the original metadata if the parser can't work with it.
                parsedMetadata = @{
                                   @"original"  : metadataStr ?: [NSNull null],
                                   @"title"     : [NSNull null],
                                   @"artist"    : [NSNull null]
                                   };
            }
            
            // Inform the delegate of the metadata if it implements RMMetadataUpdated:.
            // We pass a dictionary with keys "title", "artist" and "original" (original metadata string).
            // The parser implementation could also add other data in the dictionary (like an "image" key).
            if ( [self.delegate respondsToSelector:@selector(RMMetadataUpdated:)] ) {
                [self delegate_callMethod:@selector(RMMetadataUpdated:)
                               withObject:parsedMetadata];
            }
        }
        
    }
}









#pragma mark - ==== METADATA ====
#pragma mark Class methods
// Helpers for sending metadata to the iOS now playing info center.


// Takes an array with 2 or more elements.
// Element 1: The title.
// Element 2: The artist.
// Element 3..n: Whatever. I usually use the third element for a string with an URL that points to a UIImage (album cover).
//
// These elements are messaged to sendMediaInfoWithTitle:andArtist:andImage:.
+ (void)sendMediaInfoWithArguments:(NSArray *)arguments {
    if ( ! arguments || arguments.count < 2 ) {
        LOG_RADIOMANAGER(@"[RadioManager] +sendMediaInfoWithArguments: (The arguments parameter can't be nil and needs to have, at least, a title and an artist.)");
        return;
    }
    
    UIImage *image = arguments.count > 2 ? arguments[2] : nil;
    
    [self sendMediaInfoWithTitle:arguments[0]
                       andArtist:arguments[1]
                        andImage:image];
}


// Send the actual info to the iOS now playing info center.
+ (void)sendMediaInfoWithTitle:(NSString *)title andArtist:(NSString *)artist andImage:(UIImage *)image {
    MPNowPlayingInfoCenter *infoCenter = [MPNowPlayingInfoCenter defaultCenter];
    NSMutableDictionary *mediaInfo = [@{} mutableCopy];
    
    if ( ! infoCenter || ( ! title && ! artist && ! image ) ) {
        LOG_RADIOMANAGER(@"[RadioManager] +sendMediaInfoWithTitle:andArtist:andImage: (%@)", @"Can't send metadata to iOS now playing info center.");
        return;
    }
    
    LOG_RADIOMANAGER(@"[RadioManager] +sendMediaInfoWithTitle:andArtist:andImage: [%@] [%@] [%@]", title, artist, image);
    
    if ( title ) {
        mediaInfo[MPMediaItemPropertyTitle] = title;
    }
    
    if ( artist ) {
        mediaInfo[MPMediaItemPropertyArtist] = artist;
    }
    
    if ( image ) {
        MPMediaItemArtwork *itemArtwork         = [[MPMediaItemArtwork alloc] initWithImage:image];
        mediaInfo[MPMediaItemPropertyArtwork]   = itemArtwork;
    }
    
    if ( [mediaInfo count] > 0 ) {
        // Metadata available
        [infoCenter setNowPlayingInfo:mediaInfo];
    }
    else {
        LOG_RADIOMANAGER(@"[RadioManager] +sendMediaInfoWithTitle:andArtist:andImage: (%@)", @"No metadata to show on iOS now playing info center.");
        [self clearMediaInfoFromMediaPlayer];
    }
}


// Clears the metadata from the iOS now playing info center.
+ (void)clearMediaInfoFromMediaPlayer {
    MPNowPlayingInfoCenter *infoCenter = [MPNowPlayingInfoCenter defaultCenter];
    [infoCenter setNowPlayingInfo:nil];
}












#pragma mark - ==== BACKGROUND AUDIO SESSION / REMOTE CONTROLS ====
#pragma mark Class methods

// Enables the AVAudioSession for background audio playback.

+ (void)enableAudioSession {
    AVAudioSession *audioSession    = [AVAudioSession sharedInstance];
    NSError *error                  = nil;
    BOOL categorySet                = [audioSession setCategory:AVAudioSessionCategoryPlayback
                                                          error:&error];
    BOOL audioSessionEnabled        = categorySet && [audioSession setActive:YES
                                                                       error:&error];
    
    if ( ! audioSessionEnabled || error ) {
        if ( ! audioSession ) {
            LOG_RADIOMANAGER(@"[RadioManager] +enableAudioSession error: %@", @"Can't access the audio session shared instance.");
            return;
        }
        else {
            LOG_RADIOMANAGER(@"[RadioManager] +enableAudioSession error: %@", error.localizedDescription);
            return;
        }
    }
    
    LOG_RADIOMANAGER(@"[RadioManager] +enableAudioSession");
}

// Disables the AVAudioSession.
// This shouldn't normally be called, since the session is dropped when quitting the app.
// Useful if you want to "free" the audio session for other apps.
+ (void)disableAudioSession {
    AVAudioSession *audioSession    = [AVAudioSession sharedInstance];
    NSError *error                  = nil;
    
    if ( ! audioSession ) {
        LOG_RADIOMANAGER(@"[RadioManager] +disableAudioSession error: %@", @"Can't access the audio session shared instance.");
        return;
    }
    
    BOOL audioSessionDisabled   = [audioSession setActive:NO
                                                    error:&error];
    
    if ( ! audioSessionDisabled || error ) {
        LOG_RADIOMANAGER(@"[RadioManager] +disableBackgroundAudio error: %@", error.localizedDescription);
        return;
    }
    
    LOG_RADIOMANAGER(@"[RadioManager] +disableAudioSession");
}

// Begins the capture of iOS remote controls.
+ (void)enableRemoteControls {
    LOG_RADIOMANAGER(@"[RadioManager] +enableRemoteControls");
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
}

#pragma mark Instance methods
// Reacts to the remote controls captured and sent by the App Delegate to the radio manager.
- (void)processRemoteControlEvent:(UIEvent *)event {
    if ( event.type == UIEventTypeRemoteControl ) {
        switch ( event.subtype ) {
            case UIEventSubtypeRemoteControlPlay:
                LOG_RADIOMANAGER(@"[RadioManager] -processRemoteControlEvent: %@", @"Play");
                [self play];
                break;
                
            case UIEventSubtypeRemoteControlPause:
                LOG_RADIOMANAGER(@"[RadioManager] -processRemoteControlEvent: %@", @"Pause");
                [self pause];
                break;
                
            case UIEventSubtypeRemoteControlStop:
                LOG_RADIOMANAGER(@"[RadioManager] -processRemoteControlEvent: %@", @"Stop");
                [self stop];
                break;
                
            case UIEventSubtypeRemoteControlTogglePlayPause:
                LOG_RADIOMANAGER(@"[RadioManager] -processRemoteControlEvent: %@", @"Play/Pause");
                [self playPause];
                break;
                
            case UIEventSubtypeRemoteControlNextTrack:
            case UIEventSubtypeRemoteControlPreviousTrack:
            default:
                break;
        }
    }
}










#pragma mark - ==== REACHABILITY ====
#pragma mark Instance methods

// Configure reachability to react to internet connectivity changes.
- (void)setupReachability {
    LOG_RADIOMANAGER(@"[RadioManager] -setupReachability");
    
    // Subscribe to reachability notifications to handle network connection changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityDidChange:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    
    internetReachability = [Reachability reachabilityForInternetConnection];
    [internetReachability startNotifier];
}

// React accordingly to the reachability changes.
- (void)reachabilityDidChange:(NSNotification *)notification {
    NetworkStatus netStatus = [internetReachability currentReachabilityStatus];
    
    switch ( netStatus ) {
        case NotReachable:
            if ( self.isPlaying ) {
                self.continueAfterReachabilityChange = YES;
            }
            
            LOG_RADIOMANAGER(@"[RadioManager] -reachabilityDidChange: (%@)", @"Internet not reachable.");
            break;
            
        case ReachableViaWiFi:
            if ( self.continueAfterReachabilityChange || self.isPlaying ) {
                self.continueAfterReachabilityChange = NO;
                [self stop];
                [self play];
            }
            
            LOG_RADIOMANAGER(@"[RadioManager] -reachabilityDidChange: (%@)", @"Internet reachable via Wi-Fi.");
            break;
            
        case ReachableViaWWAN:
            if ( self.continueAfterReachabilityChange || self.isPlaying ) {
                self.continueAfterReachabilityChange = NO;
                [self stop];
                [self play];
            }
            
            LOG_RADIOMANAGER(@"[RadioManager] -reachabilityDidChange: (%@)", @"Internet reachable via mobile data.");
            break;
            
        default:
            break;
    }
    
}










#pragma mark - Private interface instance methods

// Messaging to the delegate object.
// We use "pragma" directives to avoid warnings on performSelector:

- (void)delegate_callMethod:(SEL)method {
    if ( [self.delegate respondsToSelector:method] ) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.delegate performSelector:method];
#pragma clang diagnostic pop
    }
}

- (void)delegate_callMethod:(SEL)method withObject:(id)object {
    if ( [self.delegate respondsToSelector:method] ) {
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.delegate performSelector:method
                            withObject:object];
#pragma clang diagnostic pop
        
    }
}


// Custom setters for handling KVO listeners.

- (void)setPlayer:(AVPlayer *)player {
    if ( _player ) {
        [_player removeObserver:self
                     forKeyPath:@"status"];
        [_player removeObserver:self
                     forKeyPath:@"rate"];
    }
    
    _player = player;
    
    if ( _player ) {
        [_player addObserver:self
                  forKeyPath:@"status"
                     options:kNilOptions
                     context:nil];
        [_player addObserver:self
                  forKeyPath:@"rate"
                     options:kNilOptions
                     context:nil];
    }
}

- (void)setPlayerItem:(AVPlayerItem *)playerItem {
    if ( _playerItem ) {
        [_playerItem removeObserver:self
                         forKeyPath:@"status"];
        [_playerItem removeObserver:self
                         forKeyPath:@"timedMetadata"];
    }
    
    _playerItem = playerItem;
    
    if ( _playerItem ) {
        [_playerItem addObserver:self
                      forKeyPath:@"timedMetadata"
                         options:kNilOptions
                         context:nil];
        [_playerItem addObserver:self
                      forKeyPath:@"status"
                         options:kNilOptions
                         context:nil];
    }
}

@end
