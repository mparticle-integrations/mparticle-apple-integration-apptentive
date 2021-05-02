//
//  MPKitApptentiveUtils.m
//  mParticle-Apptentive
//
//  Created by Alex Lementuev on 5/2/21.
//  Copyright © 2021 mParticle. All rights reserved.
//

#import "MPKitApptentiveUtils.h"

static id parseValue(id value) {
    if ([value isKindOfClass:[NSString class]]) {
    } else {
    }
    
    return nil;
}

NSDictionary* MPKitApptentiveParseEventInfo(NSDictionary *info) {
    NSMutableDictionary *res = [[NSMutableDictionary alloc] init];
    for (id key in info) {
        id value = info[key];
        res[key] = parseValue(value);
    }
    return res;
}
