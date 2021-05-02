//
//  MPKitApptentiveUtils.m
//  mParticle-Apptentive
//
//  Created by Alex Lementuev on 5/2/21.
//  Copyright © 2021 mParticle. All rights reserved.
//

#import "MPKitApptentiveUtils.h"

static NSNumber *parseNumber(NSString *str) {
    static NSNumberFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
    }
    
    return [formatter numberFromString:str];
}

static id parseValue(NSString *value) {
    if ([value caseInsensitiveCompare:@"true"] == NSOrderedSame) {
        return [NSNumber numberWithBool:YES];
    }
    
    if ([value caseInsensitiveCompare:@"false"] == NSOrderedSame) {
        return [NSNumber numberWithBool:NO];
    }
    
    NSNumber *number = parseNumber(value);
    if (number) {
        return number;
    }
    
    return value;
}

NSDictionary* MPKitApptentiveParseEventInfo(NSDictionary *info) {
    NSMutableDictionary *res = [[NSMutableDictionary alloc] init];
    for (id key in info) {
        id value = info[key];
        res[key] = [value isKindOfClass:[NSString class]] ? parseValue(value) : value;
    }
    return res;
}
