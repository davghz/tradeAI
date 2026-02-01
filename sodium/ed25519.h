/*
 * Ed25519 digital signature API
 * Wrapper around TweetNaCl implementation
 */

#ifndef ED25519_H
#define ED25519_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define ED25519_PUBLIC_KEY_LEN  32
#define ED25519_PRIVATE_KEY_LEN 64  /* seed + public key */
#define ED25519_SIGNATURE_LEN   64
#define ED25519_SEED_LEN        32

/* Create keypair from seed */
void ed25519_create_keypair(unsigned char *public_key,
                            unsigned char *private_key,
                            const unsigned char *seed);

/* Get public key from private key */
void ed25519_get_pubkey(unsigned char *public_key,
                        const unsigned char *private_key);

/* Sign message */
void ed25519_sign(unsigned char *signature,
                  const unsigned char *message,
                  size_t message_len,
                  const unsigned char *public_key,
                  const unsigned char *private_key);

/* Verify signature */
int ed25519_verify(const unsigned char *signature,
                   const unsigned char *message,
                   size_t message_len,
                   const unsigned char *public_key);

/* Decode base64 private key */
int ed25519_decode_private_key(const char *base64_key, 
                               unsigned char *private_key);

/* Utility functions */
int ed25519_consttime_equal(const unsigned char *x, 
                            const unsigned char *y, 
                            size_t len);
void ed25519_memzero(void *ptr, size_t len);

#ifdef __cplusplus
}
#endif

#endif /* ED25519_H */
