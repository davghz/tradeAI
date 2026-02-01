/**
 * TACoinbaseAPI+Auth.mm
 */

#import "TACoinbaseAPI+Private.h"

@implementation TACoinbaseAPI (Auth)

- (NSMutableURLRequest *)createRequest:(NSString *)path method:(NSString *)method body:(NSString *)body requiresAuth:(BOOL)requiresAuth {
    NSString *urlString = [NSString stringWithFormat:@"%@%@", self.baseURL, path];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];

    [request setHTTPMethod:method];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    if (requiresAuth) {
        NSString *jwt = [self generateJWTForMethod:method path:path];
        if (jwt.length > 0) {
            NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", jwt];
            [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        } else {
            NSLog(@"[CoinbaseAPI] Missing JWT for request %@", path);
        }
    }

    if (body) {
        [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    }

    NSLog(@"[CoinbaseAPI] Request: %@ %@", method, path);

    return request;
}

- (NSMutableURLRequest *)createRequest:(NSString *)path method:(NSString *)method body:(NSString *)body {
    return [self createRequest:path method:method body:body requiresAuth:YES];
}

- (NSMutableURLRequest *)createAuthRequest:(NSString *)path method:(NSString *)method body:(NSString *)body error:(NSError **)errorOut {
    NSString *jwt = nil;
    NSString *apiKeyForHeader = nil;
    BOOL usedEd25519 = NO;

    if ([self hasECDSACredentials]) {
        jwt = [self generateJWTForMethod:method path:path];
        if (jwt.length > 0) {
            apiKeyForHeader = TAECDSAKeyName(self);
            TACoinbaseSetDebugValue(@"debug_jwt_method", @"ECDSA");
        }
    }

    if (jwt.length == 0) {
        [self loadCredentials];
    }

    if (jwt.length == 0 && [self hasEd25519Credentials]) {
        jwt = [self generateEdDSAJWTForMethod:method path:path];
        if (jwt.length > 0) {
            apiKeyForHeader = TAEd25519KeyName(self);
            usedEd25519 = YES;
            TACoinbaseSetDebugValue(@"debug_jwt_method", @"Ed25519");
        }
    }

    if (jwt.length == 0) {
        if (errorOut) {
            *errorOut = [NSError errorWithDomain:@"CoinbaseAPI" code:401
                                        userInfo:@{NSLocalizedDescriptionKey: @"JWT generation failed (check private key format)"}];
        }
        return nil;
    }

    NSMutableURLRequest *request = [self createRequest:path method:method body:body requiresAuth:NO];
    NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", jwt];
    [request setValue:authHeader forHTTPHeaderField:@"Authorization"];

    if (apiKeyForHeader.length > 0) {
        TACoinbaseSetDebugValue(@"debug_access_key_header", @"(omitted)");
    } else if (usedEd25519) {
        TACoinbaseSetDebugValue(@"debug_access_key_header", @"(missing)");
    }

    return request;
}

@end
