/**
 * TACoinbaseAPI+JWT.mm
 */

#import "TACoinbaseAPI+Private.h"
#import "sodium/ed25519.h"
#import <CommonCrypto/CommonDigest.h>
#import <dlfcn.h>

static NSString *base64UrlEncode(NSData *data) {
    NSString *base64 = [data base64EncodedStringWithOptions:0];
    base64 = [base64 stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    base64 = [base64 stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    base64 = [base64 stringByReplacingOccurrencesOfString:@"=" withString:@""];
    return base64;
}

static NSString *const CB_API_HOST = @"api.coinbase.com";
static NSString *const CB_API_BASE_PATH = @"/api/v3/brokerage";

static NSString *TAJWTURIForMethodPath(NSString *methodUpper, NSString *path) {
    NSString *fullPath = [NSString stringWithFormat:@"%@%@", CB_API_BASE_PATH, path];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *mode = [defaults stringForKey:@"coinbase_jwt_uri_mode"];
    if ([mode isEqualToString:@"path"]) {
        TACoinbaseSetDebugValue(@"debug_jwt_uri_mode", @"path");
        return [NSString stringWithFormat:@"%@ %@", methodUpper, fullPath];
    }
    if ([mode isEqualToString:@"https"]) {
        TACoinbaseSetDebugValue(@"debug_jwt_uri_mode", @"https");
        return [NSString stringWithFormat:@"%@ https://%@%@", methodUpper, CB_API_HOST, fullPath];
    }
    TACoinbaseSetDebugValue(@"debug_jwt_uri_mode", @"host");
    return [NSString stringWithFormat:@"%@ %@%@", methodUpper, CB_API_HOST, fullPath];
}

NSString *TAECDSAKeyName(TACoinbaseAPI *api) {
    if (api.apiKey.length == 0) {
        return @"";
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id flag = [defaults objectForKey:@"coinbase_ecdsa_use_full_name"];
    BOOL useFullName = flag ? [flag boolValue] : YES;
    if (!useFullName) {
        TACoinbaseSetDebugValue(@"debug_ecdsa_key_mode", @"raw");
        NSRange range = [api.apiKey rangeOfString:@"/apiKeys/"];
        if (range.location != NSNotFound) {
            return [api.apiKey substringFromIndex:NSMaxRange(range)];
        }
        return api.apiKey;
    }
    TACoinbaseSetDebugValue(@"debug_ecdsa_key_mode", @"full");
    return api.apiKey;
}

typedef struct bio_st BIO;
typedef struct ec_key_st EC_KEY;
typedef struct ecdsa_sig_st ECDSA_SIG;
typedef struct bignum_st BIGNUM;
typedef struct evp_pkey_st EVP_PKEY;
typedef struct ec_group_st EC_GROUP;
typedef struct ec_point_st EC_POINT;

typedef struct {
    BIGNUM *r;
    BIGNUM *s;
} TAECDSASigLegacy;

typedef struct {
    void *handle;
    BIO *(*BIO_new_mem_buf)(const void *buf, int len);
    int (*BIO_free)(BIO *a);
    EC_KEY *(*PEM_read_bio_ECPrivateKey)(BIO *bp, EC_KEY **x, void *cb, void *u);
    EVP_PKEY *(*PEM_read_bio_PrivateKey)(BIO *bp, EVP_PKEY **x, void *cb, void *u);
    EC_KEY *(*EVP_PKEY_get1_EC_KEY)(EVP_PKEY *pkey);
    void (*EVP_PKEY_free)(EVP_PKEY *pkey);
    EC_KEY *(*d2i_ECPrivateKey)(EC_KEY **a, const unsigned char **pp, long length);
    int (*OBJ_txt2nid)(const char *s);
    EC_KEY *(*EC_KEY_new_by_curve_name)(int nid);
    int (*EC_KEY_set_private_key)(EC_KEY *key, const BIGNUM *priv_key);
    const EC_GROUP *(*EC_KEY_get0_group)(const EC_KEY *key);
    EC_POINT *(*EC_POINT_new)(const EC_GROUP *group);
    int (*EC_POINT_mul)(const EC_GROUP *group, EC_POINT *r, const BIGNUM *n,
                        const EC_POINT *q, const BIGNUM *m, void *ctx);
    int (*EC_KEY_set_public_key)(EC_KEY *key, const EC_POINT *pub);
    void (*EC_POINT_free)(EC_POINT *point);
    BIGNUM *(*BN_bin2bn)(const unsigned char *s, int len, BIGNUM *ret);
    void (*BN_free)(BIGNUM *bn);
    void (*EC_KEY_free)(EC_KEY *key);
    ECDSA_SIG *(*ECDSA_do_sign)(const unsigned char *dgst, int dgst_len, EC_KEY *key);
    void (*ECDSA_SIG_get0)(const ECDSA_SIG *sig, const BIGNUM **pr, const BIGNUM **ps);
    void (*ECDSA_SIG_free)(ECDSA_SIG *sig);
    int (*BN_bn2binpad)(const BIGNUM *a, unsigned char *to, int tolen);
    int (*BN_bn2bin)(const BIGNUM *a, unsigned char *to);
    int (*BN_num_bytes)(const BIGNUM *a);
    int (*OPENSSL_init_crypto)(uint64_t opts, const void *settings);
    void (*OPENSSL_add_all_algorithms_noconf)(void);
    void (*OpenSSL_add_all_algorithms)(void);
} TAOpenSSL;

static TAOpenSSL gOpenSSL;

static BOOL TAOpenSSLLoad(void) {
    if (gOpenSSL.handle) {
        return YES;
    }
    const char *candidates[] = {
        "/usr/lib/libcrypto.1.1.dylib",
        "/usr/lib/libcrypto.1.0.0.dylib",
        "/usr/lib/libcrypto.dylib"
    };
    for (size_t i = 0; i < sizeof(candidates) / sizeof(candidates[0]); i++) {
        void *handle = dlopen(candidates[i], RTLD_LAZY);
        if (!handle) {
            continue;
        }
        gOpenSSL.handle = handle;
        *(void **)(&gOpenSSL.BIO_new_mem_buf) = dlsym(handle, "BIO_new_mem_buf");
        *(void **)(&gOpenSSL.BIO_free) = dlsym(handle, "BIO_free");
        *(void **)(&gOpenSSL.PEM_read_bio_ECPrivateKey) = dlsym(handle, "PEM_read_bio_ECPrivateKey");
        *(void **)(&gOpenSSL.PEM_read_bio_PrivateKey) = dlsym(handle, "PEM_read_bio_PrivateKey");
        *(void **)(&gOpenSSL.EVP_PKEY_get1_EC_KEY) = dlsym(handle, "EVP_PKEY_get1_EC_KEY");
        *(void **)(&gOpenSSL.EVP_PKEY_free) = dlsym(handle, "EVP_PKEY_free");
        *(void **)(&gOpenSSL.d2i_ECPrivateKey) = dlsym(handle, "d2i_ECPrivateKey");
        *(void **)(&gOpenSSL.OBJ_txt2nid) = dlsym(handle, "OBJ_txt2nid");
        *(void **)(&gOpenSSL.EC_KEY_new_by_curve_name) = dlsym(handle, "EC_KEY_new_by_curve_name");
        *(void **)(&gOpenSSL.EC_KEY_set_private_key) = dlsym(handle, "EC_KEY_set_private_key");
        *(void **)(&gOpenSSL.EC_KEY_get0_group) = dlsym(handle, "EC_KEY_get0_group");
        *(void **)(&gOpenSSL.EC_POINT_new) = dlsym(handle, "EC_POINT_new");
        *(void **)(&gOpenSSL.EC_POINT_mul) = dlsym(handle, "EC_POINT_mul");
        *(void **)(&gOpenSSL.EC_KEY_set_public_key) = dlsym(handle, "EC_KEY_set_public_key");
        *(void **)(&gOpenSSL.EC_POINT_free) = dlsym(handle, "EC_POINT_free");
        *(void **)(&gOpenSSL.BN_bin2bn) = dlsym(handle, "BN_bin2bn");
        *(void **)(&gOpenSSL.BN_free) = dlsym(handle, "BN_free");
        *(void **)(&gOpenSSL.EC_KEY_free) = dlsym(handle, "EC_KEY_free");
        *(void **)(&gOpenSSL.ECDSA_do_sign) = dlsym(handle, "ECDSA_do_sign");
        *(void **)(&gOpenSSL.ECDSA_SIG_get0) = dlsym(handle, "ECDSA_SIG_get0");
        *(void **)(&gOpenSSL.ECDSA_SIG_free) = dlsym(handle, "ECDSA_SIG_free");
        *(void **)(&gOpenSSL.BN_bn2binpad) = dlsym(handle, "BN_bn2binpad");
        *(void **)(&gOpenSSL.BN_bn2bin) = dlsym(handle, "BN_bn2bin");
        *(void **)(&gOpenSSL.BN_num_bytes) = dlsym(handle, "BN_num_bytes");
        *(void **)(&gOpenSSL.OPENSSL_init_crypto) = dlsym(handle, "OPENSSL_init_crypto");
        *(void **)(&gOpenSSL.OPENSSL_add_all_algorithms_noconf) = dlsym(handle, "OPENSSL_add_all_algorithms_noconf");
        *(void **)(&gOpenSSL.OpenSSL_add_all_algorithms) = dlsym(handle, "OpenSSL_add_all_algorithms");

    BOOL ok = (gOpenSSL.BIO_new_mem_buf && gOpenSSL.BIO_free &&
               gOpenSSL.PEM_read_bio_ECPrivateKey && gOpenSSL.EC_KEY_free &&
               gOpenSSL.ECDSA_do_sign && gOpenSSL.ECDSA_SIG_free &&
               gOpenSSL.BN_bn2bin);
    if (ok) {
        if (gOpenSSL.OPENSSL_init_crypto) {
            gOpenSSL.OPENSSL_init_crypto(0, NULL);
        }
        if (gOpenSSL.OPENSSL_add_all_algorithms_noconf) {
            gOpenSSL.OPENSSL_add_all_algorithms_noconf();
        } else if (gOpenSSL.OpenSSL_add_all_algorithms) {
            gOpenSSL.OpenSSL_add_all_algorithms();
        }
        return YES;
    }
    NSMutableArray *missing = [NSMutableArray array];
    if (!gOpenSSL.BIO_new_mem_buf) [missing addObject:@"BIO_new_mem_buf"];
    if (!gOpenSSL.BIO_free) [missing addObject:@"BIO_free"];
    if (!gOpenSSL.PEM_read_bio_ECPrivateKey) [missing addObject:@"PEM_read_bio_ECPrivateKey"];
    if (!gOpenSSL.EC_KEY_free) [missing addObject:@"EC_KEY_free"];
    if (!gOpenSSL.ECDSA_do_sign) [missing addObject:@"ECDSA_do_sign"];
    if (!gOpenSSL.ECDSA_SIG_free) [missing addObject:@"ECDSA_SIG_free"];
    if (!gOpenSSL.BN_bn2bin) [missing addObject:@"BN_bn2bin"];
    if (missing.count > 0) {
        TACoinbaseSetDebugValue(@"debug_openssl_missing", [missing componentsJoinedByString:@","]);
    }
    NSMutableArray *extraMissing = [NSMutableArray array];
    if (!gOpenSSL.OBJ_txt2nid) [extraMissing addObject:@"OBJ_txt2nid"];
    if (!gOpenSSL.EC_KEY_new_by_curve_name) [extraMissing addObject:@"EC_KEY_new_by_curve_name"];
    if (!gOpenSSL.EC_KEY_set_private_key) [extraMissing addObject:@"EC_KEY_set_private_key"];
    if (!gOpenSSL.EC_KEY_get0_group) [extraMissing addObject:@"EC_KEY_get0_group"];
    if (!gOpenSSL.EC_POINT_new) [extraMissing addObject:@"EC_POINT_new"];
    if (!gOpenSSL.EC_POINT_mul) [extraMissing addObject:@"EC_POINT_mul"];
    if (!gOpenSSL.EC_KEY_set_public_key) [extraMissing addObject:@"EC_KEY_set_public_key"];
    if (!gOpenSSL.EC_POINT_free) [extraMissing addObject:@"EC_POINT_free"];
    if (!gOpenSSL.BN_bin2bn) [extraMissing addObject:@"BN_bin2bn"];
    if (!gOpenSSL.BN_free) [extraMissing addObject:@"BN_free"];
    if (extraMissing.count > 0) {
        TACoinbaseSetDebugValue(@"debug_openssl_missing_extra", [extraMissing componentsJoinedByString:@","]);
    }
        dlclose(handle);
        memset(&gOpenSSL, 0, sizeof(gOpenSSL));
    }
    return NO;
}

static NSData *TADataFromPEM(NSString *pemString) {
    if (pemString.length == 0) {
        return nil;
    }
    NSMutableString *base64 = [NSMutableString string];
    NSArray<NSString *> *lines = [pemString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        if ([line hasPrefix:@"-----BEGIN"] || [line hasPrefix:@"-----END"]) {
            continue;
        }
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length > 0) {
            [base64 appendString:trimmed];
        }
    }
    if (base64.length == 0) {
        return nil;
    }
    return [[NSData alloc] initWithBase64EncodedString:base64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
}

static BOOL TAASN1ReadLength(const uint8_t *bytes, size_t len, size_t *idx, size_t *outLen) {
    if (*idx >= len) return NO;
    uint8_t first = bytes[(*idx)++];
    if ((first & 0x80) == 0) {
        *outLen = first;
        return YES;
    }
    size_t count = first & 0x7F;
    if (count == 0 || count > sizeof(size_t) || *idx + count > len) {
        return NO;
    }
    size_t value = 0;
    for (size_t i = 0; i < count; i++) {
        value = (value << 8) | bytes[(*idx)++];
    }
    *outLen = value;
    return YES;
}

static NSData *TAExtractSEC1PrivateKeyScalar(NSData *data) {
    if (!data || data.length < 10) return nil;
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    size_t len = data.length;
    size_t idx = 0;
    if (bytes[idx++] != 0x30) return nil;
    size_t seqLen = 0;
    if (!TAASN1ReadLength(bytes, len, &idx, &seqLen)) return nil;
    if (idx + seqLen > len) return nil;
    if (bytes[idx++] != 0x02) return nil;
    size_t verLen = 0;
    if (!TAASN1ReadLength(bytes, len, &idx, &verLen)) return nil;
    idx += verLen;
    if (idx >= len || bytes[idx++] != 0x04) return nil;
    size_t keyLen = 0;
    if (!TAASN1ReadLength(bytes, len, &idx, &keyLen)) return nil;
    if (idx + keyLen > len) return nil;
    return [NSData dataWithBytes:bytes + idx length:keyLen];
}

static NSData *TAECDSASignWithOpenSSL(NSString *pemKey, NSData *message) {
    if (pemKey.length == 0 || !message) {
        return nil;
    }
    if (!TAOpenSSLLoad()) {
        TACoinbaseSetDebugValue(@"debug_openssl_stage", @"load_failed");
        return nil;
    }

    const char *pem = [pemKey UTF8String];
    if (!pem) {
        TACoinbaseSetDebugValue(@"debug_openssl_stage", @"pem_utf8_failed");
        return nil;
    }
    BIO *bio = gOpenSSL.BIO_new_mem_buf((void *)pem, -1);
    if (!bio) {
        TACoinbaseSetDebugValue(@"debug_openssl_stage", @"bio_failed");
        return nil;
    }
    EC_KEY *ecKey = gOpenSSL.PEM_read_bio_ECPrivateKey(bio, NULL, NULL, NULL);
    gOpenSSL.BIO_free(bio);
    if (!ecKey && gOpenSSL.PEM_read_bio_PrivateKey && gOpenSSL.EVP_PKEY_get1_EC_KEY) {
        BIO *fallbackBio = gOpenSSL.BIO_new_mem_buf((void *)pem, -1);
        if (fallbackBio) {
            EVP_PKEY *pkey = gOpenSSL.PEM_read_bio_PrivateKey(fallbackBio, NULL, NULL, NULL);
            gOpenSSL.BIO_free(fallbackBio);
            if (pkey) {
                ecKey = gOpenSSL.EVP_PKEY_get1_EC_KEY(pkey);
                if (gOpenSSL.EVP_PKEY_free) {
                    gOpenSSL.EVP_PKEY_free(pkey);
                }
            }
        }
    }
    if (!ecKey && gOpenSSL.d2i_ECPrivateKey) {
        NSData *der = TADataFromPEM(pemKey);
        if (der.length > 0) {
            const unsigned char *ptr = (const unsigned char *)der.bytes;
            ecKey = gOpenSSL.d2i_ECPrivateKey(NULL, &ptr, (long)der.length);
        } else {
            TACoinbaseSetDebugValue(@"debug_openssl_stage", @"der_decode_failed");
        }
    }
    if (!ecKey && gOpenSSL.BN_bin2bn && gOpenSSL.OBJ_txt2nid && gOpenSSL.EC_KEY_new_by_curve_name &&
        gOpenSSL.EC_KEY_set_private_key && gOpenSSL.EC_KEY_get0_group && gOpenSSL.EC_POINT_new &&
        gOpenSSL.EC_POINT_mul && gOpenSSL.EC_KEY_set_public_key) {
        NSData *der = TADataFromPEM(pemKey);
        if (der.length == 0) {
            TACoinbaseSetDebugValue(@"debug_openssl_stage", @"der_decode_failed");
        }
        NSData *scalar = TAExtractSEC1PrivateKeyScalar(der);
        if (!scalar || scalar.length == 0) {
            TACoinbaseSetDebugValue(@"debug_openssl_stage", @"scalar_extract_failed");
        }
        if (scalar.length > 0) {
            TACoinbaseSetDebugValue(@"debug_openssl_scalar_len", [NSString stringWithFormat:@"%lu", (unsigned long)scalar.length]);
            BIGNUM *priv = gOpenSSL.BN_bin2bn((const unsigned char *)scalar.bytes, (int)scalar.length, NULL);
            int nid = gOpenSSL.OBJ_txt2nid("prime256v1");
            EC_KEY *tmpKey = (nid > 0) ? gOpenSSL.EC_KEY_new_by_curve_name(nid) : NULL;
            if (tmpKey && priv) {
                if (gOpenSSL.EC_KEY_set_private_key(tmpKey, priv) == 1) {
                    const EC_GROUP *group = gOpenSSL.EC_KEY_get0_group(tmpKey);
                    EC_POINT *pub = group ? gOpenSSL.EC_POINT_new(group) : NULL;
                    if (pub) {
                        if (gOpenSSL.EC_POINT_mul(group, pub, priv, NULL, NULL, NULL) == 1 &&
                            gOpenSSL.EC_KEY_set_public_key(tmpKey, pub) == 1) {
                            ecKey = tmpKey;
                        }
                        gOpenSSL.EC_POINT_free(pub);
                    }
                }
            }
            if (priv && gOpenSSL.BN_free) {
                gOpenSSL.BN_free(priv);
            }
            if (!ecKey && tmpKey) {
                gOpenSSL.EC_KEY_free(tmpKey);
            }
        }
    }
    if (!ecKey) {
        TACoinbaseSetDebugValue(@"debug_openssl_stage", @"pem_read_failed");
        return nil;
    }

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(message.bytes, (CC_LONG)message.length, digest);

    ECDSA_SIG *sig = gOpenSSL.ECDSA_do_sign(digest, (int)CC_SHA256_DIGEST_LENGTH, ecKey);
    gOpenSSL.EC_KEY_free(ecKey);
    if (!sig) {
        TACoinbaseSetDebugValue(@"debug_openssl_stage", @"sign_failed");
        return nil;
    }

    const BIGNUM *r = NULL;
    const BIGNUM *s = NULL;
    if (gOpenSSL.ECDSA_SIG_get0) {
        gOpenSSL.ECDSA_SIG_get0(sig, &r, &s);
    } else {
        TAECDSASigLegacy *legacySig = (TAECDSASigLegacy *)sig;
        r = legacySig->r;
        s = legacySig->s;
    }
    if (!r || !s) {
        gOpenSSL.ECDSA_SIG_free(sig);
        TACoinbaseSetDebugValue(@"debug_openssl_stage", @"rs_missing");
        return nil;
    }

    unsigned char rbuf[32] = {0};
    unsigned char sbuf[32] = {0};

    if (gOpenSSL.BN_bn2binpad) {
        if (gOpenSSL.BN_bn2binpad(r, rbuf, sizeof(rbuf)) != (int)sizeof(rbuf) ||
            gOpenSSL.BN_bn2binpad(s, sbuf, sizeof(sbuf)) != (int)sizeof(sbuf)) {
            gOpenSSL.ECDSA_SIG_free(sig);
            TACoinbaseSetDebugValue(@"debug_openssl_stage", @"bn_pad_failed");
            return nil;
        }
    } else {
        unsigned char rtmp[32] = {0};
        unsigned char stmp[32] = {0};
        int rlen = gOpenSSL.BN_bn2bin(r, rtmp);
        int slen = gOpenSSL.BN_bn2bin(s, stmp);
        if (rlen <= 0 || slen <= 0 || rlen > (int)sizeof(rbuf) || slen > (int)sizeof(sbuf)) {
            gOpenSSL.ECDSA_SIG_free(sig);
            TACoinbaseSetDebugValue(@"debug_openssl_stage", @"bn_size_failed");
            return nil;
        }
        memcpy(rbuf + ((int)sizeof(rbuf) - rlen), rtmp, rlen);
        memcpy(sbuf + ((int)sizeof(sbuf) - slen), stmp, slen);
    }

    gOpenSSL.ECDSA_SIG_free(sig);
    TACoinbaseSetDebugValue(@"debug_openssl_stage", @"ok");

    NSMutableData *raw = [NSMutableData dataWithBytes:rbuf length:sizeof(rbuf)];
    [raw appendBytes:sbuf length:sizeof(sbuf)];
    return raw;
}

NSString *TAEd25519KeyName(TACoinbaseAPI *api) {
    if (api.ed25519ApiKey.length == 0) {
        return @"";
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id flag = [defaults objectForKey:@"coinbase_ed25519_use_full_name"];
    BOOL useFullName = flag ? [flag boolValue] : YES;
    if (!useFullName) {
        TACoinbaseSetDebugValue(@"debug_ed25519_key_mode", @"raw");
        return api.ed25519ApiKey;
    }
    TACoinbaseSetDebugValue(@"debug_ed25519_key_mode", @"full");
    if ([api.ed25519ApiKey containsString:@"/apiKeys/"]) {
        return api.ed25519ApiKey;
    }
    if (api.apiKey.length > 0) {
        NSRange range = [api.apiKey rangeOfString:@"/apiKeys/"];
        if (range.location != NSNotFound) {
            NSString *prefix = [api.apiKey substringToIndex:range.location];
            return [NSString stringWithFormat:@"%@/apiKeys/%@", prefix, api.ed25519ApiKey];
        }
    }
    return api.ed25519ApiKey;
}

@implementation TACoinbaseAPI (Auth)

- (NSString *)generateJWTForMethod:(NSString *)method path:(NSString *)path {
    if (self.apiKey.length == 0 || self.apiPrivateKey.length == 0) {
        return nil;
    }

    NSString *methodUpper = [method uppercaseString];
    NSString *uri = TAJWTURIForMethodPath(methodUpper, path);

    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    long long nbf = (long long)now;
    long long exp = nbf + 120;
    NSString *nonce = [[NSUUID UUID] UUIDString];

    NSString *keyName = TAECDSAKeyName(self);
    NSDictionary *header = @{
        @"alg": @"ES256",
        @"kid": keyName.length > 0 ? keyName : self.apiKey,
        @"nonce": nonce
    };
    NSDictionary *payload = @{
        @"iss": @"cdp",
        @"nbf": @(nbf),
        @"exp": @(exp),
        @"sub": keyName.length > 0 ? keyName : self.apiKey,
        @"uri": uri
    };

    NSError *jsonError = nil;
    NSData *headerData = [NSJSONSerialization dataWithJSONObject:header options:0 error:&jsonError];
    if (!headerData) {
        NSLog(@"[CoinbaseAPI] JWT header encode failed: %@", jsonError);
        return nil;
    }
    NSData *payloadData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
    if (!payloadData) {
        NSLog(@"[CoinbaseAPI] JWT payload encode failed: %@", jsonError);
        return nil;
    }

    NSString *headerB64 = base64UrlEncode(headerData);
    NSString *payloadB64 = base64UrlEncode(payloadData);
    NSString *signingInput = [NSString stringWithFormat:@"%@.%@", headerB64, payloadB64];

    NSData *signature = [self ecdsaSign:[signingInput dataUsingEncoding:NSUTF8StringEncoding]];
    if (!signature) {
        NSLog(@"[CoinbaseAPI] JWT ECDSA signing failed");
        return nil;
    }

    NSString *sigB64 = base64UrlEncode(signature);
    NSString *token = [NSString stringWithFormat:@"%@.%@.%@", headerB64, payloadB64, sigB64];
    if ([path hasPrefix:@"/accounts"]) {
        TACoinbaseAppendDebugLine([NSString stringWithFormat:@"JWT uri=%@ token_prefix=%@", uri, [token substringToIndex:MIN(24, token.length)]]);
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:token forKey:@"debug_last_jwt"];
        [defaults setObject:uri forKey:@"debug_last_jwt_uri"];
        [defaults setObject:methodUpper forKey:@"debug_last_jwt_method"];
        [defaults synchronize];
    }
    return token;
}

- (NSData *)ecdsaSign:(NSData *)message {
    SecKeyRef privateKey = TACoinbaseCopyECPrivateKey(self.apiPrivateKey);
    if (!privateKey) {
        NSData *fallback = TAECDSASignWithOpenSSL(self.apiPrivateKey, message);
        if (fallback) {
            TACoinbaseSetDebugValue(@"debug_sign_error", @"");
            return fallback;
        }
        TACoinbaseSetDebugValue(@"debug_sign_error", @"OpenSSL sign failed (check key/crypto)");
        return nil;
    }

    CFErrorRef error = NULL;
    CFDataRef derSig = SecKeyCreateSignature(privateKey,
                                             kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
                                             (__bridge CFDataRef)message,
                                             &error);
    CFRelease(privateKey);
    if (!derSig) {
        NSError *err = CFBridgingRelease(error);
        NSLog(@"[CoinbaseAPI] ECDSA sign failed: %@", err.localizedDescription);
        TACoinbaseSetDebugValue(@"debug_sign_error", err.localizedDescription ?: @"");
        return nil;
    }

    NSData *rawSig = TACoinbaseECDSADerToRaw((__bridge_transfer NSData *)derSig, 32);
    if (!rawSig) {
        NSLog(@"[CoinbaseAPI] Failed to convert DER signature to raw format");
        TACoinbaseSetDebugValue(@"debug_sign_error", @"DER signature conversion failed");
    } else {
        TACoinbaseSetDebugValue(@"debug_sign_error", @"");
    }
    return rawSig;
}

- (NSString *)generateEdDSAJWTForMethod:(NSString *)method path:(NSString *)path {
    if (self.ed25519ApiKey.length == 0 || self.ed25519PrivateKey.length == 0) {
        return nil;
    }

    NSString *methodUpper = [method uppercaseString];
    NSString *uri = TAJWTURIForMethodPath(methodUpper, path);
    NSString *keyName = TAEd25519KeyName(self);

    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    long long nbf = (long long)now;
    long long exp = nbf + 120;
    NSString *nonce = [[NSUUID UUID] UUIDString];

    NSDictionary *header = @{
        @"alg": @"EdDSA",
        @"kid": keyName.length > 0 ? keyName : self.ed25519ApiKey,
        @"nonce": nonce,
        @"typ": @"JWT"
    };
    NSDictionary *payload = @{
        @"iss": @"cdp",
        @"nbf": @(nbf),
        @"exp": @(exp),
        @"sub": keyName.length > 0 ? keyName : self.ed25519ApiKey,
        @"uri": uri
    };

    NSError *jsonError = nil;
    NSData *headerData = [NSJSONSerialization dataWithJSONObject:header options:0 error:&jsonError];
    if (!headerData) {
        NSLog(@"[CoinbaseAPI] Ed25519 JWT header encode failed: %@", jsonError);
        return nil;
    }
    NSData *payloadData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
    if (!payloadData) {
        NSLog(@"[CoinbaseAPI] Ed25519 JWT payload encode failed: %@", jsonError);
        return nil;
    }

    NSString *headerB64 = base64UrlEncode(headerData);
    NSString *payloadB64 = base64UrlEncode(payloadData);
    NSString *signingInput = [NSString stringWithFormat:@"%@.%@", headerB64, payloadB64];

    NSData *signature = [self ed25519Sign:[signingInput dataUsingEncoding:NSUTF8StringEncoding]];
    if (!signature) {
        NSLog(@"[CoinbaseAPI] Ed25519 JWT signing failed");
        return nil;
    }

    NSString *sigB64 = base64UrlEncode(signature);
    NSString *token = [NSString stringWithFormat:@"%@.%@.%@", headerB64, payloadB64, sigB64];

    if ([path hasPrefix:@"/accounts"]) {
        TACoinbaseAppendDebugLine([NSString stringWithFormat:@"Ed25519 JWT uri=%@ token_prefix=%@", uri, [token substringToIndex:MIN(24, token.length)]]);
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:token forKey:@"debug_last_jwt"];
        [defaults setObject:uri forKey:@"debug_last_jwt_uri"];
        [defaults setObject:@"EdDSA" forKey:@"debug_last_jwt_alg"];
        [defaults synchronize];
    }

    return token;
}

- (NSData *)ed25519Sign:(NSData *)message {
    unsigned char privateKey[ED25519_PRIVATE_KEY_LEN];
    const char *keyStr = [self.ed25519PrivateKey UTF8String];

    if (ed25519_decode_private_key(keyStr, privateKey) != 0) {
        TACoinbaseSetDebugValue(@"debug_ed25519_sign_error", @"Failed to decode Ed25519 private key");
        NSLog(@"[CoinbaseAPI] Failed to decode Ed25519 private key");
        return nil;
    }

    unsigned char publicKey[ED25519_PUBLIC_KEY_LEN];
    ed25519_get_pubkey(publicKey, privateKey);

    unsigned char signature[ED25519_SIGNATURE_LEN];
    ed25519_sign(signature,
                 (const unsigned char *)message.bytes,
                 message.length,
                 publicKey,
                 privateKey);

    ed25519_memzero(privateKey, sizeof(privateKey));

    TACoinbaseSetDebugValue(@"debug_ed25519_sign_error", @"");
    return [NSData dataWithBytes:signature length:ED25519_SIGNATURE_LEN];
}

@end
