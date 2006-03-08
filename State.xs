#define PERL_NO_GET_CONTEXT

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef USE_ITHREADS

/* from threasd.xs  */

/* Values for 'state' member */
#define PERL_ITHR_JOINABLE		0
#define PERL_ITHR_DETACHED		1
#define PERL_ITHR_FINISHED		4
#define PERL_ITHR_JOINED		2

typedef struct ithread_s {
    struct ithread_s *next;	/* Next thread in the list */
    struct ithread_s *prev;	/* Prev thread in the list */
    PerlInterpreter *interp;	/* The threads interpreter */
    I32 tid;              	/* Threads module's thread id */
    perl_mutex mutex; 		/* Mutex for updating things in this struct */
    I32 count;			/* How many SVs have a reference to us */
    signed char state;		/* Are we detached ? */
    int gimme;			/* Context of create */
    SV* init_function;          /* Code to run */
    SV* params;                 /* Args to pass function */
#ifdef WIN32
	DWORD	thr;            /* OS's idea if thread id */
	HANDLE handle;          /* OS's waitable handle */
#else
  	pthread_t thr;          /* OS's handle for the thread */
#endif
} ithread;


#define state_is_joined(thread)    ithread_state_is_joined(aTHX_ thread)
#define state_is_finished(thread)  ithread_state_is_finished(aTHX_ thread)
#define state_is_detached(thread)  ithread_state_is_detached(aTHX_ thread)
#define state_is_running(thread)   ithread_state_is_running(aTHX_ thread)
#define state_is_joinable(thread)  ithread_state_is_joinable(aTHX_ thread)


ithread* Thread_State_get_ithread_580 (pTHX) {
    ithread*  thread;
    SV*       thr_sv;
    int       count;

    dSP;
    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSVpv("threads", 0)));
    PUTBACK;
    count = call_method("self", G_SCALAR);

    if (count != 1)
       croak("%s\n","Internal error, couldn't call thread->self");

    thr_sv = POPs;
    thread = INT2PTR(ithread*, SvIV(SvRV(thr_sv)));

    PUTBACK;
    FREETMPS;
    LEAVE;

    return thread;
}


/* from threasd.xs > Perl 5.8.1 */

ithread* Thread_State_get_ithread_581 (pTHX) {
    /*  The original code is "threads::self". but its length is 12! */
    /*  So we can use "threads::sel"                                */
    SV** thread_sv = hv_fetch(PL_modglobal, "threads::sel", 12, 0);
    if(!thread_sv) {
        croak("%s\n","Internal error, couldn't get TLS");
    }
    return INT2PTR(ithread*,SvIV(*thread_sv));
}


#if PERL_SUBVERSION < 1
# define state_get_ithread(sv)    Thread_State_get_ithread_580(aTHX)
#else
# define state_get_ithread(sv)    Thread_State_get_ithread_581(aTHX)
#endif


ithread* state_sv_to_ithread(pTHX_ SV *sv) {
    ithread*     thread;

    if (SvROK(sv)) {
        thread = INT2PTR(ithread*, SvIV(SvRV(sv)));
    }
    else {
        thread = state_get_ithread(aTHX);
    }
    return thread;
}


int ithread_state_is (pTHX_ SV* sv, signed char state) {
    ithread*  thread;
    thread = state_sv_to_ithread(aTHX_ sv);
    return (thread->state & state) ? 1 : 0;
}


int ithread_state_is_running (pTHX_ SV* sv) {
    return !ithread_state_is(aTHX_ sv, PERL_ITHR_FINISHED);
}


int ithread_state_is_finished (pTHX_ SV* sv) {
    return ithread_state_is(aTHX_ sv, PERL_ITHR_FINISHED);
}


int ithread_state_is_detached (pTHX_ SV* sv) {
    return ithread_state_is(aTHX_ sv, PERL_ITHR_DETACHED);
}


int ithread_state_is_joined (pTHX_ SV* sv) {
    return ithread_state_is(aTHX_ sv, PERL_ITHR_JOINED);
}


int ithread_state_is_joinable (pTHX_ SV* sv) {
    ithread*  thread;
    thread = state_sv_to_ithread(aTHX_ sv);
    return (    !(thread->state & PERL_ITHR_DETACHED)
             && !(thread->state & PERL_ITHR_JOINED)
           ) ? 1 : 0;
}


#endif /* USE_ITHREADS */



MODULE = Thread::State	PACKAGE = threads	PREFIX = state_	

PROTOTYPES: DISABLE

#ifdef USE_ITHREADS

int
state_is_running (obj)
	SV* obj

int
state_is_finished (obj)
	SV* obj

int
state_is_detached (obj)
	SV* obj

int
state_is_joined (obj)
	SV* obj

int
state_is_joinable (obj)
	SV* obj

#endif /* USE_ITHREADS */

