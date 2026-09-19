#include <assert.h>
#include <stdio.h>
#include "../PrivacyPolicy.h"
int main(void){
 for(double c=5;c<=75;c+=1){
 assert(veilProgressForComfort(c,c)==0);assert(veilFullBlurAngle(c)-c>=40);
 assert(veilProgressForComfort(veilFullBlurAngle(c),c)==1);
 double prev=0;for(double a=0;a<=180;a+=.1){double p=veilProgressForComfort(a,c);assert(isfinite(p)&&p>=prev&&p>=0&&p<=1);assert(p==veilProgressForComfort(-a,c));prev=p;}}
 assert(veilProgressForComfort(10,5)>0);assert(veilProgressForComfort(10,15)==0);
 // A delayed frame must never jump to near-full blur in one presentation.
 assert(veilFollow(0,1,1.)<=2.5/30.+1e-9);
 assert(veilFollow(1,0,1.)>=1.-2.5/30.-1e-9);
 double p=0;for(int i=0;i<180;i++){double n=veilFollow(p,1,1./60.);assert(n>=p&&n-p<=2.5/60.+1e-9);p=n;}assert(p>.999);
 for(int i=0;i<180;i++)p=veilFollow(p,0,1./60.);assert(p<.001);
 double samples[]={179,-179,178,-178};double m=veilCircularMean(samples,4);assert(veilSpread(samples,4,m)<3);
 puts("PASS: 5–75 degree range, no zero denominator, smooth wide-zone ramp, symmetric response, bounded stalled-frame step, continuous recovery");
}
