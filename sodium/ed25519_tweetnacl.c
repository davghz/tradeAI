/*
 * Ed25519 wrapper around TweetNaCl
 * TweetNaCl is a compact, verified implementation
 */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "tweetnacl.h"
#include "ed25519.h"

/* TweetNaCl uses crypto_sign_ed25519_* prefix, we wrap to ed25519_* */

void ed25519_create_keypair(unsigned char *public_key,
                            unsigned char *private_key,
                            const unsigned char *seed) {
    /* TweetNaCl: crypto_sign_keypair(pk, sk) generates both from random */
    /* We need to derive from seed: sk = seed, pk = seed * base */
    
    /* Copy seed as the first 32 bytes of private key */
    memcpy(private_key, seed, 32);
    
    /* Derive public key using TweetNaCl's scalar multiplication */
    /* The public key is the result of clamped seed * base point */
    
    /* Clamp the scalar as per Ed25519 spec */
    unsigned char az[64];
    memcpy(az, seed, 32);
    az[0] &= 248;
    az[31] &= 63;
    az[31] |= 64;
    
    /* Use TweetNaCl's scalar mult base - crypto_scalarmult_base */
    crypto_scalarmult_base(public_key, az);
    
    /* Append public key to private key (standard Ed25519 format) */
    memcpy(private_key + 32, public_key, 32);
}

void ed25519_get_pubkey(unsigned char *public_key, const unsigned char *private_key) {
    /* Simply copy the last 32 bytes of the private key */
    memcpy(public_key, private_key + 32, 32);
}

void ed25519_sign(unsigned char *signature,
                  const unsigned char *message,
                  size_t message_len,
                  const unsigned char *public_key,
                  const unsigned char *private_key) {
    (void)public_key; /* Not used, but kept for API compatibility */
    
    unsigned long long sig_len;
    unsigned char *sig = malloc(message_len + 64);
    if (!sig) return;
    
    /* TweetNaCl: crypto_sign(sm, &smlen, m, mlen, sk) */
    /* Returns: sm = signature || message, smlen = len(sm) */
    crypto_sign(sig, &sig_len, message, message_len, private_key);
    
    /* Extract just the signature (first 64 bytes) */
    memcpy(signature, sig, 64);
    
    free(sig);
}

int ed25519_verify(const unsigned char *signature,
                   const unsigned char *message,
                   size_t message_len,
                   const unsigned char *public_key) {
    unsigned char *sm = malloc(64 + message_len);
    unsigned char *m = malloc(64 + message_len);
    if (!sm || !m) {
        free(sm);
        free(m);
        return 0;
    }
    
    /* Reconstruct signed message: signature || message */
    memcpy(sm, signature, 64);
    memcpy(sm + 64, message, message_len);
    
    unsigned long long mlen;
    
    /* TweetNaCl: crypto_sign_open(m, &mlen, sm, smlen, pk) */
    /* Returns 0 on success, -1 on failure */
    int result = crypto_sign_open(m, &mlen, sm, 64 + message_len, public_key);
    
    free(sm);
    free(m);
    
    return (result == 0) ? 1 : 0;
}

/* Base64 decode */
static size_t base64_decode(const char *in, unsigned char *out, size_t out_len) {
    static const int d[] = {
        62,-1,-1,-1,63,52,53,54,55,56,57,58,59,60,61,-1,
        -1,-1,-2,-1,-1,-1,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,
        15,16,17,18,19,20,21,22,23,24,25,-1,-1,-1,-1,-1,-1,
        26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,
        43,44,45,46,47,48,49,50,51
    };
    size_t i, j = 0;
    int val = 0, valb = -8;
    for (i = 0; in[i] && j < out_len; i++) {
        unsigned char c = (unsigned char)in[i];
        if (c < 43 || c > 122) continue;
        int c2 = d[c - 43];
        if (c2 < 0) continue;
        val = (val << 6) + c2;
        valb += 6;
        if (valb >= 0) {
            out[j++] = (unsigned char)((val >> valb) & 0xFF);
            valb -= 8;
        }
    }
    return j;
}

static int is_base64_char(char c) {
    return ((c >= 'A' && c <= 'Z') ||
            (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') ||
            c == '+' || c == '/' || c == '=');
}

static int extract_seed_from_der(const unsigned char *buf, size_t len, unsigned char *seed_out) {
    /* Look for an OCTET STRING of length 32: 0x04 0x20 <32 bytes> */
    for (size_t i = 0; i + 34 <= len; i++) {
        if (buf[i] == 0x04 && buf[i + 1] == 0x20) {
            memcpy(seed_out, buf + i + 2, 32);
            return 0;
        }
    }
    return -1;
}

int ed25519_decode_private_key(const char *base64_key, unsigned char *private_key) {
    if (!base64_key || !private_key) {
        return -1;
    }

    /* Handle PEM input by extracting base64 and decoding DER */
    if (strstr(base64_key, "BEGIN") != NULL) {
        char b64[512];
        size_t j = 0;
        for (size_t i = 0; base64_key[i] != '\0' && j < sizeof(b64) - 1; i++) {
            if (is_base64_char(base64_key[i])) {
                b64[j++] = base64_key[i];
            }
        }
        b64[j] = '\0';

        unsigned char der[256];
        size_t n = base64_decode(b64, der, sizeof(der));
        if (n > 0) {
            unsigned char seed[ED25519_SEED_LEN];
            if (extract_seed_from_der(der, n, seed) == 0) {
                unsigned char pubkey[ED25519_PUBLIC_KEY_LEN];
                ed25519_create_keypair(pubkey, private_key, seed);
                ed25519_memzero(seed, sizeof(seed));
                ed25519_memzero(pubkey, sizeof(pubkey));
                return 0;
            }
        }
        return -1;
    }

    unsigned char buf[64];
    size_t n = base64_decode(base64_key, buf, sizeof(buf));
    
    if (n == 32) {
        /* Got 32 bytes - this is the seed */
        unsigned char pubkey[ED25519_PUBLIC_KEY_LEN];
        ed25519_create_keypair(pubkey, private_key, buf);
        ed25519_memzero(pubkey, sizeof(pubkey));
        ed25519_memzero(buf, sizeof(buf));
        return 0;
    } else if (n == 64) {
        /* Got 64 bytes - this is seed || public key */
        memcpy(private_key, buf, 64);
        ed25519_memzero(buf, sizeof(buf));
        return 0;
    }
    
    /* Try hex format (32-byte seed) */
    if (strlen(base64_key) == 64) {
        unsigned char seed[ED25519_SEED_LEN];
        for (size_t i = 0; i < 32; i++) {
            unsigned int b;
            if (sscanf(base64_key + i*2, "%2x", &b) != 1) return -1;
            seed[i] = (unsigned char)b;
        }
        unsigned char pubkey[ED25519_PUBLIC_KEY_LEN];
        ed25519_create_keypair(pubkey, private_key, seed);
        ed25519_memzero(seed, sizeof(seed));
        ed25519_memzero(pubkey, sizeof(pubkey));
        return 0;
    }
    
    return -1;
}

int ed25519_consttime_equal(const unsigned char *x, const unsigned char *y, size_t len) {
    unsigned char r = 0;
    for (size_t i = 0; i < len; i++) {
        r |= x[i] ^ y[i];
    }
    return (int)(1 & ((r - 1) >> 8));
}

void ed25519_memzero(void *ptr, size_t len) {
    volatile unsigned char *p = ptr;
    while (len--) *p++ = 0;
}
