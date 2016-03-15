//
//  AppDelegate.h
//
//  Copyright © 2016 Alejandro Iván Melo Domínguez
//  All rights reserved.
//  www.penquistas.cl
//

#import <Foundation/Foundation.h>
#import "RadioManagerMetadataParser.h"

@interface RadioManagerParser : NSObject <RadioManagerMetadataParser>

#pragma mark - Singleton
// Shared instance for this particular parser.
+ (instancetype)sharedParser;

#pragma mark - Parser
// Implement this method to implement your own parser for the metadata string.
- (NSDictionary *)dictionaryFromMetadata:(NSString *)metadata;

@end