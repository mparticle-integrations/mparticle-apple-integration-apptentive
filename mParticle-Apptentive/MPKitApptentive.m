//
//  MPKitApptentive.m
//
//  Copyright 2016 mParticle, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "MPKitApptentive.h"

#if defined(__has_include) && __has_include(<Apptentive/Apptentive.h>)
#import <Apptentive/Apptentive.h>
#else
#import "Apptentive.h"
#endif

NSString * const apptentiveAppKeyKey = @"apptentiveAppKey";
NSString * const apptentiveAppSignatureKey = @"apptentiveAppSignature";

@interface MPKitApptentive ()

// iOS 8 and earlier
@property (strong, nonatomic) NSString *firstName;
@property (strong, nonatomic) NSString *lastName;

// iOS 9 and later
@property (strong, nonatomic) NSPersonNameComponents *nameComponents;
@property (strong, nonatomic) NSPersonNameComponentsFormatter *nameFormatter;

@end

@implementation MPKitApptentive

+ (NSNumber *)kitCode {
    return @(97);
}

+ (void)load {
    MPKitRegister *kitRegister = [[MPKitRegister alloc] initWithName:@"Apptentive" className:@"MPKitApptentive"];
    [MParticle registerExtension:kitRegister];
}

#pragma mark - MPKitInstanceProtocol methods

#pragma mark Kit instance and lifecycle
- (MPKitExecStatus *)didFinishLaunchingWithConfiguration:(NSDictionary *)configuration {
    MPKitExecStatus *execStatus = nil;

    NSString *appKey = configuration[apptentiveAppKeyKey];
    NSString *appSignature = configuration[apptentiveAppSignatureKey];

    if (appKey == nil || appSignature == nil) {
        if (appKey == nil) {
            NSLog(@"No Apptentive App Key provided.");
        }

        if (appSignature == nil) {
            NSLog(@"No Apptentive App Signature provided.");
        }

        NSLog(@"Please see the Apptentive mParticle integration guide: https://learn.apptentive.com/knowledge-base/mparticle-integration-ios/");
    }
    
    if (!appKey || !appSignature) {
        execStatus = [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode] returnCode:MPKitReturnCodeRequirementsNotMet];
        return execStatus;
    }

    _configuration = configuration;

    [self start];

    execStatus = [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode] returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (void)start {
    static dispatch_once_t kitPredicate;

    dispatch_once(&kitPredicate, ^{
        NSString *appKey = self.configuration[apptentiveAppKeyKey];
        NSString *appSignature = self.configuration[apptentiveAppSignatureKey];
        
        ApptentiveConfiguration *apptentiveConfig = [ApptentiveConfiguration configurationWithApptentiveKey:appKey apptentiveSignature:appSignature];
        
        apptentiveConfig.distributionName = @"mParticle";
        apptentiveConfig.distributionVersion = [MParticle sharedInstance].version;
        
        [Apptentive registerWithConfiguration:apptentiveConfig];

        _started = YES;

        if ([NSPersonNameComponents class]) {
            _nameFormatter = [[NSPersonNameComponentsFormatter alloc] init];
            _nameComponents = [[NSPersonNameComponents alloc] init];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *userInfo = @{mParticleKitInstanceKey:[[self class] kitCode]};

            [[NSNotificationCenter defaultCenter] postNotificationName:mParticleKitDidBecomeActiveNotification
                                                                object:nil
                                                              userInfo:userInfo];
        });
    });
}

- (id const)providerKitInstance {
    if (![self started]) {
        return nil;
    } else {
        return [Apptentive sharedConnection];
    }
}

#pragma mark User attributes and identities

- (MPKitExecStatus *)setUserAttribute:(NSString *)key value:(NSString *)value {
    if ([key isEqualToString:mParticleUserAttributeFirstName]) {
        if (self.nameComponents) {
            self.nameComponents.givenName = value;
        } else {
            self.firstName = value;
        }
    } else if ([key isEqualToString:mParticleUserAttributeLastName]) {
        if (self.nameComponents) {
            self.nameComponents.familyName = value;
        } else {
            self.lastName = value;
        }
    } else {
        [[Apptentive sharedConnection] addCustomPersonDataString:value withKey:key];
    }

    NSString *name = nil;

    if (self.nameComponents) {
        name = [self.nameFormatter stringFromPersonNameComponents:self.nameComponents];
    } else {
        if (self.firstName.length && self.lastName.length) {
            name = [@[ self.firstName, self.lastName ] componentsJoinedByString:@" "];
        } else if (self.firstName.length) {
            name = self.firstName;
        } else if (self.lastName.length) {
            name = self.lastName;
        }
    }

    if (name) {
        [Apptentive sharedConnection].personName = name;
    }

    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode] returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (MPKitExecStatus *)removeUserAttribute:(NSString *)key {
    [[Apptentive sharedConnection] removeCustomPersonDataWithKey:key];
    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode] returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (MPKitExecStatus *)setUserIdentity:(NSString *)identityString identityType:(MPUserIdentity)identityType {
    MPKitReturnCode returnCode;

    if (identityType == MPUserIdentityEmail) {
        [Apptentive sharedConnection].personEmailAddress = identityString;
        returnCode = MPKitReturnCodeSuccess;
    } else if (identityType == MPUserIdentityCustomerId) {
        if ([Apptentive sharedConnection].personName.length == 0) {
            [Apptentive sharedConnection].personName = identityString;
        }
        returnCode = MPKitReturnCodeSuccess;
    } else {
        returnCode = MPKitReturnCodeRequirementsNotMet;
    }

    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode] returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

#pragma mark e-Commerce

- (NSString *)nameForCommerceEventAction:(MPCommerceEventAction)action {
    switch (action) {
        case MPCommerceEventActionAddToCart:
            return @"Add To Cart";
        case MPCommerceEventActionRemoveFromCart:
            return @"Remove From Cart";
        case MPCommerceEventActionAddToWishList:
            return @"Add To Wish List";
        case MPCommerceEventActionRemoveFromWishlist:
            return @"Remove From Wishlist";
        case MPCommerceEventActionCheckout:
            return @"Checkout";
        case MPCommerceEventActionCheckoutOptions:
            return @"Checkout Options";
        case MPCommerceEventActionClick:
            return @"Click";
        case MPCommerceEventActionViewDetail:
            return @"View Detail";
        case MPCommerceEventActionPurchase:
            return @"Purchase";
        case MPCommerceEventActionRefund:
            return @"Refund";
    }
}

- (MPKitExecStatus *)logCommerceEvent:(MPCommerceEvent *)commerceEvent {
    MPTransactionAttributes *transactionAttributes = commerceEvent.transactionAttributes;
    NSMutableArray *commerceItems = [NSMutableArray arrayWithCapacity:commerceEvent.products.count];
    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode] returnCode:MPKitReturnCodeSuccess forwardCount:0];

    for (MPProduct *product in commerceEvent.products) {
        NSDictionary *item = [Apptentive extendedDataCommerceItemWithItemID:product.sku name:product.name category:product.category price:product.price quantity:product.quantity currency:commerceEvent.currency];

        [commerceItems addObject:item];
        [execStatus incrementForwardCount];
    }

    NSDictionary *commerceData = [Apptentive extendedDataCommerceWithTransactionID:transactionAttributes.transactionId affiliation:transactionAttributes.affiliation revenue:transactionAttributes.revenue shipping:transactionAttributes.shipping tax:transactionAttributes.tax currency:commerceEvent.currency commerceItems:commerceItems];
    [execStatus incrementForwardCount];

    NSString *eventName = [NSString stringWithFormat:@"eCommerce - %@", [self nameForCommerceEventAction:commerceEvent.action]];
    [[Apptentive sharedConnection] engage:eventName withCustomData:nil withExtendedData:@[commerceData] fromViewController:nil];
    [execStatus incrementForwardCount];

    return execStatus;
}

#pragma mark Events

- (MPKitExecStatus *)logEvent:(MPEvent *)event {
    NSDictionary *eventValues = event.info;
    if ([eventValues count] > 0) {
        [[Apptentive sharedConnection] engage:event.name withCustomData:eventValues fromViewController:nil];
    } else {
        [[Apptentive sharedConnection] engage:event.name fromViewController:nil];
    }
    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode] returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

@end
