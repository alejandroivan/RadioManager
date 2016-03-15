//
//  AppDelegate.h
//
//  Copyright © 2016 Alejandro Iván Melo Domínguez
//  All rights reserved.
//  www.penquistas.cl
//

#ifndef RadioManagerMetadataParser_h
#define RadioManagerMetadataParser_h

/*
 This protocol defines two methods that metadata parsers should implement.
 All parsers should have a singleton element which is used as required. If you need to parse different metadata,
 then you should have to have another singleton from a different class that implements this protocol.
 The method that actually parses the data (and will change according to your needs) is dictionaryFromMetadata:.
 
 For example, if you have two streams that have different metadata, let's say:
 1) artist|track|duration
 2) artist - track (duration)
 
 You should have two parsers of different classes that parse that particular data, for example:
 
 @interface FirstParser <RadioManagerMetadataParser>
 + (instancetype)sharedParser;
 - (NSDictionary *)dictionaryFromMetadata:(NSString *)metadata; // A particular implementation of this method
 @end
 
 @interface SecondParser <RadioManagerMetadataParser>
 + (instancetype)sharedParser;
 - (NSDictionary *)dictionaryFromMetadata:(NSString *)metadata; // Different implementation than the one in FirstParser
 @end
 */

#pragma mark - Metadata parser protocol



@protocol RadioManagerMetadataParser <NSObject>
@required



// You should only have one instance of a parser for a particular metadata.
// Any other sources of metadata should have their own class which implement this protocol to parse that particular metadata.
+ (instancetype)sharedParser;

// This method runs in the background to parse the metadata received from the server.
// Takes a string with the raw metadata, parses it and returns it as a dictionary to the radio manager,
// which delivers it to the UIViewController or other type of object that controls the radio manager.
- (NSDictionary *)dictionaryFromMetadata:(NSString *)metadata;



@end



#endif /* RadioManagerMetadataParser_h */
