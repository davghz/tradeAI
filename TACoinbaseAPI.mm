/**
 * TACoinbaseAPI.mm
 * Coinbase Advanced Trade API v3 with ECDSA + Ed25519 Authentication
 */

#import "TACoinbaseAPI+Private.h"

static NSString *TANormalizePEMKeyIfNeeded(NSString *key) {
    if (key.length == 0) {
        return key;
    }
    if ([key rangeOfString:@"BEGIN"].location == NSNotFound) {
        return key;
    }
    if ([key rangeOfString:@"\n"].location != NSNotFound) {
        return key;
    }
    NSString *normalized = [key stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    NSString *header = nil;
    NSString *footer = nil;
    if ([normalized containsString:@"-----BEGIN EC PRIVATE KEY-----"]) {
        header = @"-----BEGIN EC PRIVATE KEY-----";
        footer = @"-----END EC PRIVATE KEY-----";
    } else if ([normalized containsString:@"-----BEGIN PRIVATE KEY-----"]) {
        header = @"-----BEGIN PRIVATE KEY-----";
        footer = @"-----END PRIVATE KEY-----";
    }
    if (!header || !footer) {
        return key;
    }
    NSRange headerRange = [normalized rangeOfString:header];
    NSRange footerRange = [normalized rangeOfString:footer];
    if (headerRange.location == NSNotFound || footerRange.location == NSNotFound) {
        return key;
    }
    NSUInteger bodyStart = NSMaxRange(headerRange);
    if (footerRange.location <= bodyStart) {
        return key;
    }
    NSString *body = [normalized substringWithRange:NSMakeRange(bodyStart, footerRange.location - bodyStart)];
    NSCharacterSet *ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSMutableString *bodyClean = [NSMutableString string];
    for (NSUInteger i = 0; i < body.length; i++) {
        unichar c = [body characterAtIndex:i];
        if (![ws characterIsMember:c]) {
            [bodyClean appendFormat:@"%C", c];
        }
    }
    NSMutableString *wrapped = [NSMutableString string];
    const NSUInteger lineLen = 64;
    for (NSUInteger i = 0; i < bodyClean.length; i += lineLen) {
        NSUInteger chunk = MIN(lineLen, bodyClean.length - i);
        [wrapped appendString:[bodyClean substringWithRange:NSMakeRange(i, chunk)]];
        [wrapped appendString:@"\n"];
    }
    return [NSString stringWithFormat:@"%@\n%@%@", header, wrapped, footer];
}

@implementation TAOrder
@end

@implementation TAAccount
@end

@implementation TAMarketData
@end

@implementation TACoinbaseAPI

+ (instancetype)sharedInstance {
    static TACoinbaseAPI *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _baseURL = @"https://api.coinbase.com/api/v3/brokerage";
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30.0;
        config.timeoutIntervalForResource = 60.0;
        _session = [NSURLSession sessionWithConfiguration:config];

        // Load credentials from UserDefaults
        [self loadCredentials];
    }
    return self;
}

- (void)loadCredentials {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Load ECDSA credentials
    NSString *apiKey = [defaults stringForKey:@"coinbase_api_key"];
    NSString *privateKey = [defaults stringForKey:@"coinbase_private_key"];

    if (apiKey.length > 0 && privateKey.length > 0) {
        NSString *trimmedKey = [apiKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *normalizedPrivate = TANormalizePEMKeyIfNeeded([privateKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]);
        self.apiKey = trimmedKey;
        self.apiPrivateKey = normalizedPrivate;
        if (![normalizedPrivate isEqualToString:privateKey]) {
            [defaults setObject:normalizedPrivate forKey:@"coinbase_private_key"];
        }
        NSLog(@"[CoinbaseAPI] Loaded ECDSA credentials from UserDefaults");
    }

    // Load Ed25519 credentials
    NSString *ed25519ApiKey = [defaults stringForKey:@"coinbase_ed25519_api_key"];
    NSString *ed25519PrivateKey = [defaults stringForKey:@"coinbase_ed25519_private_key"];

    if (ed25519ApiKey.length > 0 && ed25519PrivateKey.length > 0) {
        self.ed25519ApiKey = [ed25519ApiKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        self.ed25519PrivateKey = [ed25519PrivateKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSLog(@"[CoinbaseAPI] Loaded Ed25519 credentials from UserDefaults");
    } else {
        NSString *edPath = [[NSBundle mainBundle] pathForResource:@"linux2" ofType:@"json"];
        if (edPath) {
            NSData *data = [NSData dataWithContentsOfFile:edPath];
            if (data) {
                NSError *error = nil;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                if ([json isKindOfClass:[NSDictionary class]] && !error) {
                    NSString *kid = json[@"id"];
                    NSString *key = json[@"privateKey"];
                    if (kid.length > 0 && key.length > 0) {
                        self.ed25519ApiKey = [kid stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        self.ed25519PrivateKey = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        [defaults setObject:self.ed25519ApiKey forKey:@"coinbase_ed25519_api_key"];
                        [defaults setObject:self.ed25519PrivateKey forKey:@"coinbase_ed25519_private_key"];
                        [defaults synchronize];
                        NSLog(@"[CoinbaseAPI] Loaded Ed25519 credentials from bundle");
                    }
                }
            }
        }
    }
}

- (void)setAPIKey:(NSString *)apiKey apiPrivateKey:(NSString *)privateKey {
    self.apiKey = [apiKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.apiPrivateKey = TANormalizePEMKeyIfNeeded([privateKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]);
    NSLog(@"[CoinbaseAPI] ECDSA credentials configured");
}

- (void)setEd25519APIKey:(NSString *)apiKey ed25519PrivateKey:(NSString *)privateKey {
    self.ed25519ApiKey = [apiKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.ed25519PrivateKey = [privateKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSLog(@"[CoinbaseAPI] Ed25519 credentials configured");
}

- (BOOL)isConfigured {
    return (self.apiKey.length > 0 && self.apiPrivateKey.length > 0) ||
           (self.ed25519ApiKey.length > 0 && self.ed25519PrivateKey.length > 0);
}

- (BOOL)hasEd25519Credentials {
    return self.ed25519ApiKey.length > 0 && self.ed25519PrivateKey.length > 0;
}

- (BOOL)hasECDSACredentials {
    return self.apiKey.length > 0 && self.apiPrivateKey.length > 0;
}

@end
