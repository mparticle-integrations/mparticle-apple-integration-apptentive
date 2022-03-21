#import "MPKitApptentive.h"
#import "MPKitApptentiveUtils.h"

#if defined(__has_include) && __has_include(<ApptentiveKit/ApptentiveKit-Swift.h>)
#import <ApptentiveKit/ApptentiveKit-Swift.h>
#else
#import "ApptentiveKit-Swift.h"
#endif


static NSString * const apptentiveAppKeyKey = @"apptentiveAppKey";
static NSString * const apptentiveAppSignatureKey = @"apptentiveAppSignature";
static NSString * const apptentiveInitOnStart = @"apptentiveInitOnStart";
static NSString * const apptentiveEnableTypeDetectionKey = @"enableTypeDetection";

NSString * const ApptentiveConversationStateDidChangeNotification = @"ApptentiveConversationStateDidChangeNotification";

// we need to keep the credentials in order to init the SDK later on
static NSString * _apptentiveKey = nil;
static NSString * _apptentiveSignature = nil;

@interface MPKitApptentive ()

// iOS 8 and earlier
@property (strong, nonatomic) NSString *firstName;
@property (strong, nonatomic) NSString *lastName;

// iOS 9 and later
@property (strong, nonatomic) NSPersonNameComponents *nameComponents;
@property (strong, nonatomic) NSPersonNameComponentsFormatter *nameFormatter;

@property (assign, nonatomic) BOOL enableTypeDetection;

@end

@interface NSNumber (ApptentiveBoolean)

- (BOOL)apptentive_isBoolean;

@end

@implementation NSNumber (ApptentiveBoolean)

- (BOOL)apptentive_isBoolean {
    CFTypeID boolID = CFBooleanGetTypeID();
    CFTypeID numID = CFGetTypeID((__bridge CFTypeRef)(self));
    return numID == boolID;
}

@end

@implementation MPKitApptentive

+ (NSNumber *)kitCode {
    return @(97);
}

+ (void)load {
    MPKitRegister *kitRegister = [[MPKitRegister alloc] initWithName:@"Apptentive" className:@"MPKitApptentive"];
    [MParticle registerExtension:kitRegister];
}

- (MPKitExecStatus *)execStatus:(MPKitReturnCode)returnCode {
    return [[MPKitExecStatus alloc] initWithSDKCode:self.class.kitCode returnCode:returnCode];
}

#pragma mark - MPKitInstanceProtocol methods

#pragma mark Kit instance and lifecycle
- (MPKitExecStatus *)didFinishLaunchingWithConfiguration:(NSDictionary *)configuration {
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
        return [self execStatus:MPKitReturnCodeRequirementsNotMet];
    }
    
    self.enableTypeDetection = [configuration objectForKey:apptentiveEnableTypeDetectionKey] != nil ? [configuration[apptentiveEnableTypeDetectionKey] boolValue] : YES;

    _configuration = configuration;

    [self start];

    return [self execStatus:MPKitReturnCodeSuccess];
}

- (void)start {
    static dispatch_once_t kitPredicate;

    dispatch_once(&kitPredicate, ^{
        _apptentiveKey = self.configuration[apptentiveAppKeyKey];
        _apptentiveSignature = self.configuration[apptentiveAppSignatureKey];

        // do we need to init the SDK while the Kit starts
        BOOL initOnStart = self.configuration[apptentiveInitOnStart] == nil ||   // if flag is missing
        [self.configuration[apptentiveInitOnStart] boolValue]; // or set to 'YES'

        if (initOnStart) {
            [[self class] registerSDK];
        } else {
            NSLog(@"Apptentive SDK was not initialized on startup");
        }

        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(conversationStateChangedNotification:) name:ApptentiveConversationStateDidChangeNotification object:nil];

        self->_started = YES;

        if ([NSPersonNameComponents class]) {
            self->_nameFormatter = [[NSPersonNameComponentsFormatter alloc] init];
            self->_nameComponents = [[NSPersonNameComponents alloc] init];
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
    return [self started] ? Apptentive.shared : nil;
}

+ (BOOL)registerSDK {
    if (_apptentiveKey.length == 0) {
        NSLog(@"Unable to initialize Apptentive SDK: apptentive key is nil or empty");
        return NO;
    }

    if (_apptentiveSignature.length == 0) {
        NSLog(@"Unable to initialize Apptentive SDK: apptentive signature is nil or empty");
        return NO;
    }

    NSLog(@"Registering Apptentive SDK");
    ApptentiveConfiguration *apptentiveConfig = [ApptentiveConfiguration configurationWithApptentiveKey:_apptentiveKey apptentiveSignature:_apptentiveSignature];

    apptentiveConfig.distributionName = @"mParticle";
    apptentiveConfig.distributionVersion = [MParticle sharedInstance].version;

    [Apptentive registerWithConfiguration:apptentiveConfig];

    return YES;
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
        [Apptentive.shared addCustomPersonDataString:value withKey:key];
        if (self.enableTypeDetection) {
            id typedValue = MPKitApptentiveParseValue(value);
            if ([typedValue isKindOfClass:[NSNumber class]]) {
                if ([typedValue apptentive_isBoolean]) {
                    [Apptentive.shared addCustomPersonDataBool:typedValue withKey:[NSString stringWithFormat:@"%@_flag", key]];
                } else {
                    [Apptentive.shared addCustomPersonDataNumber:typedValue withKey:[NSString stringWithFormat:@"%@_number", key]];
                }
            }
        }
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
        Apptentive.shared.personName = name;
    }

    return [self execStatus:MPKitReturnCodeSuccess];
}

- (MPKitExecStatus *)removeUserAttribute:(NSString *)key {
    [Apptentive.shared removeCustomPersonDataWithKey:key];
    return [self execStatus:MPKitReturnCodeSuccess];
}

- (MPKitExecStatus *)setUserIdentity:(NSString *)identityString identityType:(MPUserIdentity)identityType {
    MPKitReturnCode returnCode;

    if (identityType == MPUserIdentityEmail) {
        Apptentive.shared.personEmailAddress = identityString;
        returnCode = MPKitReturnCodeSuccess;
    } else if (identityType == MPUserIdentityCustomerId) {
        if (Apptentive.shared.personName.length == 0) {
            Apptentive.shared.personName = identityString;
        }
        returnCode = MPKitReturnCodeSuccess;
    } else {
        returnCode = MPKitReturnCodeRequirementsNotMet;
    }

    return [self execStatus:returnCode];
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

- (nonnull MPKitExecStatus *)logBaseEvent:(nonnull MPBaseEvent *)event {
    if ([event isKindOfClass:[MPEvent class]]) {
        return [self routeEvent:(MPEvent *)event];
    } else if ([event isKindOfClass:[MPCommerceEvent class]]) {
        return [self routeCommerceEvent:(MPCommerceEvent *)event];
    } else {
        return [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceAppboy) returnCode:MPKitReturnCodeUnavailable];
    }
}

- (MPKitExecStatus *)routeCommerceEvent:(MPCommerceEvent *)commerceEvent {
    if (commerceEvent.kind == MPCommerceEventKindProduct) {
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
    return [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode] returnCode:MPKitReturnCodeUnavailable];
}

#pragma mark Events

- (MPKitExecStatus *)routeEvent:(MPEvent *)event {
    NSDictionary *eventValues = event.customAttributes;
    if ([eventValues count] > 0) {
        [Apptentive.shared engage:event.name withCustomData:[self parseEventInfoDictionary:eventValues] fromViewController:nil];
    } else {
        [Apptentive.shared engage:event.name fromViewController:nil];
    }
    return [self execStatus:MPKitReturnCodeSuccess];
}

#pragma mark Screen Events

- (MPKitExecStatus *)logScreen:(MPEvent *)event {
    return [self logBaseEvent:event];
}

#pragma mark Conversation state

- (void)conversationStateChangedNotification:(NSNotification *)notification {
    NSNumber *currentUserId = MParticle.sharedInstance.identity.currentUser.userId;

    [Apptentive.shared setMParticleId:[currentUserId isEqualToNumber:@0] ? nil : currentUserId.stringValue];
}

#pragma mark Helpers

- (NSDictionary *)parseEventInfoDictionary:(NSDictionary *)info {
    NSMutableDictionary *res = [[NSMutableDictionary alloc] init];
    for (id key in info) {
        id value = info[key];
        res[key] = value;
        
        if (self.enableTypeDetection) {
            id typedValue = MPKitApptentiveParseValue(value);
            if ([typedValue isKindOfClass:[NSNumber class]]) {
                if ([typedValue apptentive_isBoolean]) {
                    res[[NSString stringWithFormat:@"%@_flag", key]] = typedValue;
                } else {
                    res[[NSString stringWithFormat:@"%@_number", key]] = typedValue;
                }
            }
        }
    }
    return res;
}

@end
