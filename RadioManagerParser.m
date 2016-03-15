//
//  AppDelegate.h
//
//  Copyright © 2016 Alejandro Iván Melo Domínguez
//  All rights reserved.
//  www.penquistas.cl
//

#import "RadioManagerParser.h"

#pragma mark - Singleton
static RadioManagerParser *__radioManagerParser;

@implementation RadioManagerParser

+ (instancetype)sharedParser {
    @synchronized( self ) {
        if ( ! __radioManagerParser ) {
            __radioManagerParser = [[self alloc] init];
        }
    }
    
    return __radioManagerParser;
}


#pragma mark - Parser

- (NSDictionary *)dictionaryFromMetadata:(NSString *)metadata {
    // Custom implementation, every parser you define should have a different one
    // depending on the metadata that the server provides.
    
    // This particular implementation is for the metadata provided by this stream URL:
    // http://sonando.us.digitalproserver.com/lacentral_aac
    // It delivers metadata in the format: title  -  artist | by digitalproserver.com
    // so we just take the title and artist.
    //
    // In your own implementation, other fields could be present. Add them by adding a new
    // key-value pair in the response NSDictionary.
    
    NSMutableArray *components      = nil;
    NSDictionary *parsedMetadata    = nil;
    
    components = [[metadata componentsSeparatedByString:@" | "] mutableCopy];
    [components removeLastObject];
    components = [[[components componentsJoinedByString:@" | "] componentsSeparatedByString:@"  -  "] mutableCopy];
    
    NSString *original  = metadata              ?: nil;
    NSString *artist    = components.count > 0  ? [components objectAtIndex:0]  : nil;
    NSString *title     = components.count > 1  ? [components objectAtIndex:1]  : nil;
    
    original            = original.length   > 0 ? original  : nil;
    artist              = artist.length     > 0 ? artist    : nil;
    title               = title.length      > 0 ? title     : nil;

    parsedMetadata = @{
                       @"original"  : original  ?: [NSNull null],
                       @"artist"    : artist    ?: [NSNull null],
                       @"title"     : title     ?: [NSNull null]
                       };
    
    return parsedMetadata;
}

@end
