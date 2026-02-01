/*
 * Random bytes implementation for TweetNaCl
 * Uses arc4random on iOS
 */

#include <stdlib.h>
#include <Availability.h>
#include <AvailabilityInternal.h>

/* Use arc4random on iOS */
extern void arc4random_buf(void *buf, size_t nbytes);

void randombytes(unsigned char *buf, unsigned long long buflen) {
    arc4random_buf(buf, (size_t)buflen);
}
