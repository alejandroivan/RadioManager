# RadioManager
A radio manager implementation for playing HTTP radio streams.
Steps:

1. Create your project.
2. Drag all files of RadioManager (including Reachability ones) to your project.
3. Enable "copy items if needed".
4. Click "finish"."

## Usage

### UIViewController

```
#import "RadioManager.h" // Import the library
#import "MyCustomRadioManagerMetadataParser.h" // Import your custom metadata parser (example at RadioManagerParser.h/.m)

// ...

@interface YourViewControllerSubclass () <RadioManagerDelegate> // Implement the delegate protocol
// ...
@end

// ...

- (void)viewDidLoad {
    [super viewDidLoad];
    // ...
    [RadioManager enableAudioSession]; // Enable the audio session for background playback
    [RadioManager enableRemoteControls]; // Enable iOS now playing info center remote controls (play/pause)

    // Set this UIViewController as the delegate
    [[RadioManager sharedManager] setDelegate:self];
    
    // Set your metadata parser (custom implementation)
    [[RadioManager sharedManager] setMetadataParser:[MyCustomRadioManagerMetadataParser sharedParser]];

    // Play a stream
    [[RadioManager sharedManager] setStreamUrl:@"http://..."] // URL of your stream
    [[RadioManager sharedManager] play];

    // Instead of the two lines above, you could use:
    // [[RadioManager sharedManager] playStreamUrl:@"http://..."];
    // The same line with other URL will play this other URL and stop the first one.
}

// ...

#pragma mark Delegate protocol implementation
- (void)RMPaused {
    NSLog(@"The stream has been paused!");
}

- (void)RMStopped {
    NSLog(@"The stream is stopped!");
    [RadioManager clearMediaInfoFromMediaPlayer]; // Clear the metadata from the iOS now playing info center
}

- (void)RMPlaying {
    NSLog(@"The stream is playing!");
}

- (void)RMLoading { // Buffering/connecting/etc.
    NSLog(@"The streaming is loading!");
}

- (void)RMMetadataUpdated:(NSDictionary *)metadata {
    NSLog(@"Metadata received.\nOriginal metadata: %@\nArtist: %@\nTitle: %@\nDictionary: %@", metadata[@"original"], metadata[@"artist"], metadata[@"title"], metadata);

    [RadioManager sendMediaInfoWithTitle:metadata[@"title"]
                               andArtist:metadata[@"artist"]
                                andImage:nil]; // Album cover (UIImage).
}
```

### RadioManagerMetadataParser

The implementation of the RadioManagerParser is fairly simple. Just implement an NSObject with two methods (one class and one instance method). That parser needs to conform to the RadioManagerMetadataParser protocol. So...

```
// ...
#import "RadioManagerMetadataParser.h" // Import the protocol description

@interface RadioManagerParser : NSObject <RadioManagerMetadataParser> // Implement the protocol

// Methods that you need to implement
+ (instancetype)sharedParser;
- (NSDictionary *)dictionaryFromMetadata:(NSString *)metadata;

@end
```

A good example of this parser is found in `RadioManagerParser.h`. In fact, just modify this file if you want.

### App Delegate
The App Delegate of your app needs to implement these two methods for catching remote control events:
```
#pragma mark - RadioManager remote controls
- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    [[RadioManager sharedManager] processRemoteControlEvent:event];
}

- (BOOL) canBecomeFirstResponder {
    return YES;
}
```


**And that's it.**

Read `RadioManager.h` for playback control methods (look for the "Playback" section).