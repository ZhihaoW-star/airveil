#ifndef PRIVACY_POLICY_H
#define PRIVACY_POLICY_H
#include <math.h>
#include <stdbool.h>
#include <stddef.h>
static inline double veilWrap(double angle) { return remainder(angle,360.0); }
static inline double veilCircularMean(const double *values,size_t count) {
 double sx=0,sy=0;for(size_t i=0;i<count;i++){sx+=cos(values[i]*M_PI/180);sy+=sin(values[i]*M_PI/180);}return atan2(sy,sx)*180/M_PI;
}
static inline double veilSpread(const double *values,size_t count,double mean) {
 double largest=0;for(size_t i=0;i<count;i++)largest=fmax(largest,fabs(veilWrap(values[i]-mean)));return largest;
}
static inline double veilFullBlurAngle(double comfort) {return fmax(78.0,comfort+40.0);}
static inline double veilProgressForComfort(double degrees,double comfort) {
 if(!isfinite(degrees)||!isfinite(comfort))return 0;
 comfort=fmax(5,fmin(75,comfort));
 double t=fmin(1.0,fmax(0.0,(fabs(degrees)-comfort)/(veilFullBlurAngle(comfort)-comfort)));
 return t*t*(3.0-2.0*t);
}
static inline double veilProgress(double degrees) {return veilProgressForComfort(degrees,28);}
static inline bool veilShouldPresent(double progress,bool wasVisible) {
 // A transparent but ordered NSWindow is still eligible for the system's
 // window screenshot picker. Remove it once clear; retain the window/filter
 // objects in memory. A subpixel deadband prevents rapid order-in/out chatter.
 if(!isfinite(progress))return wasVisible;
 return progress>(wasVisible?.0005:.001);
}
static inline double veilFollow(double current,double target,double dt) {
 // Do not catch up in one visible jump after a stalled frame.
 double stepTime=fmax(0,fmin(dt,1.0/30.0));
 double delta=(target-current)*(1.0-exp(-stepTime/(target>current?0.095:0.18)));
 double limit=2.5*stepTime;
 return current+fmax(-limit,fmin(limit,delta));
}
static inline double veilDemoProgress(double t) {
 if(t<0||t>6)return 0;
 if(t<2.0){double x=t/2.0;return x*x*(3-2*x);}
 if(t<3.0)return 1;
 double x=fmin(1,(t-3.0)/2.2);return 1-x*x*(3-2*x);
}
#endif
