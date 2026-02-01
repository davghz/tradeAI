/**
 * TACoinbaseAPI+Private.h
 */

#import "TACoinbaseAPI.h"
#import <Security/Security.h>

NS_ASSUME_NONNULL_BEGIN

@interface TACoinbaseAPI ()
@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy) NSString *apiPrivateKey;
@property (nonatomic, copy) NSString *ed25519ApiKey;
@property (nonatomic, copy) NSString *ed25519PrivateKey;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, copy) NSString *baseURL;

- (void)loadCredentials;
- (BOOL)hasEd25519Credentials;
- (BOOL)hasECDSACredentials;

- (NSString *)generateJWTForMethod:(NSString *)method path:(NSString *)path;
- (NSString *)generateEdDSAJWTForMethod:(NSString *)method path:(NSString *)path;
- (NSData *)ecdsaSign:(NSData *)message;
- (NSData *)ed25519Sign:(NSData *)message;

- (NSMutableURLRequest *)createRequest:(NSString *)path method:(NSString *)method body:(NSString *)body requiresAuth:(BOOL)requiresAuth;
- (NSMutableURLRequest *)createRequest:(NSString *)path method:(NSString *)method body:(NSString *)body;
- (NSMutableURLRequest *)createAuthRequest:(NSString *)path method:(NSString *)method body:(NSString *)body error:(NSError **)errorOut;

@end

FOUNDATION_EXPORT void TACoinbaseAppendDebugLine(NSString *line);
FOUNDATION_EXPORT void TACoinbaseSetDebugValue(NSString *key, NSString *value);
FOUNDATION_EXPORT SecKeyRef _Nullable TACoinbaseCopyECPrivateKey(NSString *keyString);
FOUNDATION_EXPORT NSData * _Nullable TACoinbaseECDSADerToRaw(NSData *derSig, size_t keySize);
FOUNDATION_EXPORT NSString *TAECDSAKeyName(TACoinbaseAPI *api);
FOUNDATION_EXPORT NSString *TAEd25519KeyName(TACoinbaseAPI *api);

NS_ASSUME_NONNULL_END
