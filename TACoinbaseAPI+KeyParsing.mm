/**
 * TACoinbaseAPI+KeyParsing.mm
 */

#import "TACoinbaseAPI+Private.h"

static NSData *base64DecodeString(NSString *string) {
    if (string.length == 0) {
        return nil;
    }
    return [[NSData alloc] initWithBase64EncodedString:string options:NSDataBase64DecodingIgnoreUnknownCharacters];
}

static NSString *filterBase64Characters(NSString *string) {
    if (string.length == 0) {
        return @"";
    }
    NSMutableString *base64 = [NSMutableString string];
    NSCharacterSet *valid = [NSCharacterSet characterSetWithCharactersInString:
                             @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="];
    for (NSUInteger i = 0; i < string.length; i++) {
        unichar c = [string characterAtIndex:i];
        if ([valid characterIsMember:c]) {
            [base64 appendFormat:@"%C", c];
        }
    }
    return base64;
}

static NSString *stripPEMHeaders(NSString *pem) {
    if (pem.length == 0) {
        return @"";
    }
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"-----BEGIN[^-]*-----|-----END[^-]*-----"
                                                                           options:0
                                                                             error:&error];
    if (!regex || error) {
        return pem;
    }
    NSMutableString *mutableString = [pem mutableCopy];
    [regex replaceMatchesInString:mutableString
                          options:0
                            range:NSMakeRange(0, mutableString.length)
                     withTemplate:@""];
    return mutableString;
}

static NSData *dataFromPEMOrBase64(NSString *keyString) {
    if (keyString.length == 0) {
        return nil;
    }
    NSString *trimmed = [keyString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return nil;
    }
    NSString *normalized = [trimmed stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"\\r" withString:@"\r"];
    BOOL looksLikePEM = ([normalized containsString:@"BEGIN"] ||
                         [normalized containsString:@"END"] ||
                         [normalized containsString:@"-----"]);
    if (looksLikePEM) {
        NSString *noHeaders = stripPEMHeaders(normalized);
        NSString *b64 = filterBase64Characters(noHeaders);
        return base64DecodeString(b64);
    }
    NSString *b64 = filterBase64Characters(normalized);
    return base64DecodeString(b64);
}

static BOOL asn1ReadLength(const uint8_t *bytes, size_t length, size_t *index, size_t *outLen) {
    if (*index >= length) return NO;
    uint8_t lenByte = bytes[(*index)++];
    if ((lenByte & 0x80) == 0) {
        *outLen = lenByte;
        return YES;
    }
    uint8_t count = lenByte & 0x7F;
    if (count == 0 || count > 2 || *index + count > length) {
        return NO;
    }
    size_t val = 0;
    for (uint8_t i = 0; i < count; i++) {
        val = (val << 8) | bytes[(*index)++];
    }
    *outLen = val;
    return YES;
}

static BOOL asn1SkipLength(const uint8_t *bytes, size_t length, size_t *index, size_t *outLen) {
    return asn1ReadLength(bytes, length, index, outLen);
}

static BOOL asn1IsPKCS8PrivateKey(NSData *data) {
    if (!data || data.length < 10) return NO;
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    size_t len = data.length;
    size_t idx = 0;
    if (bytes[idx++] != 0x30) return NO;
    size_t seqLen = 0;
    if (!asn1SkipLength(bytes, len, &idx, &seqLen)) return NO;
    if (idx + seqLen > len) return NO;
    if (bytes[idx++] != 0x02) return NO;
    size_t verLen = 0;
    if (!asn1SkipLength(bytes, len, &idx, &verLen)) return NO;
    idx += verLen;
    if (idx >= len) return NO;
    return bytes[idx] == 0x30;
}

static BOOL asn1IsSEC1PrivateKey(NSData *data) {
    if (!data || data.length < 10) return NO;
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    size_t len = data.length;
    size_t idx = 0;
    if (bytes[idx++] != 0x30) return NO;
    size_t seqLen = 0;
    if (!asn1SkipLength(bytes, len, &idx, &seqLen)) return NO;
    if (idx + seqLen > len) return NO;
    if (bytes[idx++] != 0x02) return NO;
    size_t verLen = 0;
    if (!asn1SkipLength(bytes, len, &idx, &verLen)) return NO;
    idx += verLen;
    if (idx >= len) return NO;
    return bytes[idx] == 0x04;
}

static NSData *extractSEC1PrivateKeyScalar(NSData *data) {
    if (!data || data.length < 10) return nil;
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    size_t len = data.length;
    size_t idx = 0;
    if (bytes[idx++] != 0x30) return nil;
    size_t seqLen = 0;
    if (!asn1ReadLength(bytes, len, &idx, &seqLen)) return nil;
    if (idx + seqLen > len) return nil;
    if (bytes[idx++] != 0x02) return nil;
    size_t verLen = 0;
    if (!asn1ReadLength(bytes, len, &idx, &verLen)) return nil;
    idx += verLen;
    if (idx >= len || bytes[idx++] != 0x04) return nil;
    size_t keyLen = 0;
    if (!asn1ReadLength(bytes, len, &idx, &keyLen)) return nil;
    if (idx + keyLen > len) return nil;
    return [NSData dataWithBytes:bytes + idx length:keyLen];
}

static void appendASN1Length(NSMutableData *data, NSUInteger length) {
    if (length < 0x80) {
        uint8_t len = (uint8_t)length;
        [data appendBytes:&len length:1];
        return;
    }
    if (length <= 0xFF) {
        uint8_t bytes[2] = {0x81, (uint8_t)length};
        [data appendBytes:bytes length:2];
        return;
    }
    uint8_t bytes[3] = {0x82, (uint8_t)(length >> 8), (uint8_t)(length & 0xFF)};
    [data appendBytes:bytes length:3];
}

static void appendASN1TagAndLength(NSMutableData *data, uint8_t tag, NSUInteger length) {
    [data appendBytes:&tag length:1];
    appendASN1Length(data, length);
}

static NSData *wrapECPrivateKeyPKCS8(NSData *sec1Key) {
    if (!sec1Key || sec1Key.length == 0) {
        return nil;
    }
    const uint8_t oidEcPublicKey[] = {0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01};
    const uint8_t oidPrime256v1[] = {0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07};

    NSMutableData *alg = [NSMutableData data];
    appendASN1TagAndLength(alg, 0x06, sizeof(oidEcPublicKey));
    [alg appendBytes:oidEcPublicKey length:sizeof(oidEcPublicKey)];
    appendASN1TagAndLength(alg, 0x06, sizeof(oidPrime256v1));
    [alg appendBytes:oidPrime256v1 length:sizeof(oidPrime256v1)];

    NSMutableData *algSeq = [NSMutableData data];
    appendASN1TagAndLength(algSeq, 0x30, alg.length);
    [algSeq appendData:alg];

    NSMutableData *pkcs8Body = [NSMutableData data];
    uint8_t version = 0x00;
    appendASN1TagAndLength(pkcs8Body, 0x02, 1);
    [pkcs8Body appendBytes:&version length:1];
    [pkcs8Body appendData:algSeq];
    appendASN1TagAndLength(pkcs8Body, 0x04, sec1Key.length);
    [pkcs8Body appendData:sec1Key];

    NSMutableData *pkcs8 = [NSMutableData data];
    appendASN1TagAndLength(pkcs8, 0x30, pkcs8Body.length);
    [pkcs8 appendData:pkcs8Body];
    return pkcs8;
}

static NSString *describeCFError(CFErrorRef error) {
    if (!error) return @"";
    NSError *err = CFBridgingRelease(error);
    if (!err) return @"";
    return err.localizedDescription ?: @"";
}

static SecKeyRef tryCreateKeyWithData(NSData *data, NSDictionary *attrs, NSString *label, NSMutableArray *attempts) {
    if (!data) return NULL;
    CFErrorRef error = NULL;
    SecKeyRef key = SecKeyCreateWithData((__bridge CFDataRef)data,
                                         (__bridge CFDictionaryRef)attrs,
                                         &error);
    if (key) {
        if (label.length > 0) {
            [attempts addObject:[NSString stringWithFormat:@"%@:OK", label]];
        }
        return key;
    }
    NSString *errDesc = describeCFError(error);
    if (label.length > 0) {
        if (errDesc.length > 0) {
            [attempts addObject:[NSString stringWithFormat:@"%@:%@", label, errDesc]];
        } else {
            [attempts addObject:[NSString stringWithFormat:@"%@:ERR", label]];
        }
    }
    return NULL;
}

static SecKeyRef tryCreateKeyWithSecItemAdd(NSData *data, NSDictionary *attrs, NSString *label, NSMutableArray *attempts) {
    if (!data || !attrs) return NULL;
    NSMutableDictionary *query = [attrs mutableCopy];
    query[(id)kSecClass] = (id)kSecClassKey;
    query[(id)kSecValueData] = data;
    query[(id)kSecReturnRef] = @YES;
    query[(id)kSecAttrIsPermanent] = @NO;
    query[(id)kSecAttrAccessible] = (id)kSecAttrAccessibleAfterFirstUnlock;
    if (label.length > 0) {
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"com.tradeai.app";
        NSData *tag = [[NSString stringWithFormat:@"%@.%@", bundleId, label] dataUsingEncoding:NSUTF8StringEncoding];
        query[(id)kSecAttrApplicationTag] = tag;
    }

    SecKeyRef key = NULL;
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&key);
    if (status == errSecDuplicateItem) {
        SecItemDelete((__bridge CFDictionaryRef)query);
        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&key);
    }
    if (status != errSecSuccess) {
        NSString *desc = (__bridge_transfer NSString *)SecCopyErrorMessageString(status, NULL);
        NSString *msg = desc.length > 0 ? [NSString stringWithFormat:@"%@ (%d)", desc, (int)status] : [NSString stringWithFormat:@"OSStatus %d", (int)status];
        if (label.length > 0) {
            [attempts addObject:[NSString stringWithFormat:@"%@:%@", label, msg]];
        }
        if (key) {
            CFRelease(key);
        }
        return NULL;
    }
    if (label.length > 0) {
        [attempts addObject:[NSString stringWithFormat:@"%@:OK", label]];
    }
    return key;
}

static NSData *normalizeECPrivateKeyData(NSData *keyData) {
    if (!keyData) return nil;
    if (asn1IsPKCS8PrivateKey(keyData)) {
        TACoinbaseSetDebugValue(@"debug_key_format", @"PKCS8");
        TACoinbaseSetDebugValue(@"debug_key_len", [NSString stringWithFormat:@"%lu", (unsigned long)keyData.length]);
        return keyData;
    }
    if (asn1IsSEC1PrivateKey(keyData)) {
        NSData *wrapped = wrapECPrivateKeyPKCS8(keyData);
        TACoinbaseSetDebugValue(@"debug_key_format", @"SEC1");
        TACoinbaseSetDebugValue(@"debug_key_len", [NSString stringWithFormat:@"%lu", (unsigned long)keyData.length]);
        TACoinbaseSetDebugValue(@"debug_key_wrapped_len", [NSString stringWithFormat:@"%lu", (unsigned long)wrapped.length]);
        return wrapped;
    }
    TACoinbaseSetDebugValue(@"debug_key_format", @"UNKNOWN");
    TACoinbaseSetDebugValue(@"debug_key_len", [NSString stringWithFormat:@"%lu", (unsigned long)keyData.length]);
    return keyData;
}

SecKeyRef TACoinbaseCopyECPrivateKey(NSString *keyString) {
    NSData *keyData = dataFromPEMOrBase64(keyString);
    if (!keyData) {
        TACoinbaseSetDebugValue(@"debug_key_import_error", @"Key decode failed (empty data)");
        return NULL;
    }
    NSData *normalized = normalizeECPrivateKeyData(keyData);
    if (normalized.length == 0) {
        TACoinbaseSetDebugValue(@"debug_key_import_error", @"Key normalization failed");
        return NULL;
    }

    NSMutableArray *attempts = [NSMutableArray array];

    NSDictionary *attrsPrime256 = @{
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
        (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPrivate,
        (id)kSecAttrKeySizeInBits: @256,
        (id)kSecAttrIsPermanent: @NO
    };
    NSDictionary *attrsPrimeNoSize = @{
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
        (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPrivate,
        (id)kSecAttrIsPermanent: @NO
    };
    NSDictionary *attrsEC = @{
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeEC,
        (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPrivate,
        (id)kSecAttrKeySizeInBits: @256,
        (id)kSecAttrIsPermanent: @NO
    };
    NSDictionary *attrsECNoSize = @{
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeEC,
        (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPrivate,
        (id)kSecAttrIsPermanent: @NO
    };

    SecKeyRef key = NULL;
    key = tryCreateKeyWithData(normalized, attrsPrime256, @"pkcs8:prime256", attempts);
    if (!key) key = tryCreateKeyWithData(normalized, attrsPrimeNoSize, @"pkcs8:prime256:nosize", attempts);
    if (!key) key = tryCreateKeyWithData(normalized, attrsEC, @"pkcs8:ec", attempts);
    if (!key) key = tryCreateKeyWithData(normalized, attrsECNoSize, @"pkcs8:ec:nosize", attempts);

    NSData *rawScalar = nil;
    if (!key && asn1IsSEC1PrivateKey(keyData)) {
        rawScalar = extractSEC1PrivateKeyScalar(keyData);
        if (rawScalar.length > 0) {
            TACoinbaseSetDebugValue(@"debug_key_scalar_len", [NSString stringWithFormat:@"%lu", (unsigned long)rawScalar.length]);
            key = tryCreateKeyWithData(rawScalar, attrsPrime256, @"raw:prime256", attempts);
            if (!key) key = tryCreateKeyWithData(rawScalar, attrsPrimeNoSize, @"raw:prime256:nosize", attempts);
            if (!key) key = tryCreateKeyWithData(rawScalar, attrsEC, @"raw:ec", attempts);
            if (!key) key = tryCreateKeyWithData(rawScalar, attrsECNoSize, @"raw:ec:nosize", attempts);
        }
    }

    if (!key && normalized != keyData) {
        key = tryCreateKeyWithData(keyData, attrsPrime256, @"sec1:prime256", attempts);
        if (!key) key = tryCreateKeyWithData(keyData, attrsPrimeNoSize, @"sec1:prime256:nosize", attempts);
        if (!key) key = tryCreateKeyWithData(keyData, attrsEC, @"sec1:ec", attempts);
        if (!key) key = tryCreateKeyWithData(keyData, attrsECNoSize, @"sec1:ec:nosize", attempts);
    }

    if (!key) {
        key = tryCreateKeyWithSecItemAdd(normalized, attrsPrime256, @"add:pkcs8:prime256", attempts);
        if (!key) key = tryCreateKeyWithSecItemAdd(normalized, attrsPrimeNoSize, @"add:pkcs8:prime256:nosize", attempts);
        if (!key) key = tryCreateKeyWithSecItemAdd(normalized, attrsEC, @"add:pkcs8:ec", attempts);
        if (!key) key = tryCreateKeyWithSecItemAdd(normalized, attrsECNoSize, @"add:pkcs8:ec:nosize", attempts);
        if (!key && rawScalar.length > 0) {
            key = tryCreateKeyWithSecItemAdd(rawScalar, attrsPrime256, @"add:raw:prime256", attempts);
            if (!key) key = tryCreateKeyWithSecItemAdd(rawScalar, attrsPrimeNoSize, @"add:raw:prime256:nosize", attempts);
            if (!key) key = tryCreateKeyWithSecItemAdd(rawScalar, attrsEC, @"add:raw:ec", attempts);
            if (!key) key = tryCreateKeyWithSecItemAdd(rawScalar, attrsECNoSize, @"add:raw:ec:nosize", attempts);
        }
        if (!key && keyData) {
            key = tryCreateKeyWithSecItemAdd(keyData, attrsPrime256, @"add:sec1:prime256", attempts);
        }
    }

    if (!key) {
        TACoinbaseSetDebugValue(@"debug_key_import_error", @"Key import failed (see debug_key_attempts)");
        TACoinbaseSetDebugValue(@"debug_key_attempts", [attempts componentsJoinedByString:@" | "]);
    } else {
        TACoinbaseSetDebugValue(@"debug_key_import_error", @"");
        TACoinbaseSetDebugValue(@"debug_key_attempts", [attempts componentsJoinedByString:@" | "]);
    }
    return key;
}

NSData *TACoinbaseECDSADerToRaw(NSData *derSig, size_t keySize) {
    if (!derSig) return nil;
    const uint8_t *bytes = (const uint8_t *)derSig.bytes;
    size_t len = derSig.length;
    size_t idx = 0;
    if (len < 8 || bytes[idx++] != 0x30) return nil;
    size_t seqLen = 0;
    if (!asn1ReadLength(bytes, len, &idx, &seqLen)) return nil;
    if (idx + seqLen > len) return nil;

    if (bytes[idx++] != 0x02) return nil;
    size_t rLen = 0;
    if (!asn1ReadLength(bytes, len, &idx, &rLen)) return nil;
    if (idx + rLen > len) return nil;
    const uint8_t *rPtr = bytes + idx;
    idx += rLen;

    if (bytes[idx++] != 0x02) return nil;
    size_t sLen = 0;
    if (!asn1ReadLength(bytes, len, &idx, &sLen)) return nil;
    if (idx + sLen > len) return nil;
    const uint8_t *sPtr = bytes + idx;

    NSMutableData *raw = [NSMutableData dataWithLength:keySize * 2];
    uint8_t *rawBytes = (uint8_t *)raw.mutableBytes;

    size_t rCopy = rLen > keySize ? keySize : rLen;
    size_t sCopy = sLen > keySize ? keySize : sLen;
    memcpy(rawBytes + (keySize - rCopy), rPtr + (rLen - rCopy), rCopy);
    memcpy(rawBytes + keySize + (keySize - sCopy), sPtr + (sLen - sCopy), sCopy);

    return raw;
}
