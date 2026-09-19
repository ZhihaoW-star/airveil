#ifndef CONNECTION_POLICY_H
#define CONNECTION_POLICY_H
#include <math.h>
#include <stddef.h>
// Keep trying while the session is running, with a bounded low-power cadence.
static inline double veilReconnectDelay(size_t attempt) {
 const double delays[]={5,10,20,30};return delays[attempt<4?attempt:3];
}
#endif
