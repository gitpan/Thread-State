#define PERL_NO_GET_CONTEXT

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef USE_ITHREADS

/* from threasd.xs  */

/* Values for 'state' member */
#define PERL_ITHR_JOINABLE      0
#define PERL_ITHR_DETACHED      1
#define PERL_ITHR_JOINED        2
#define PERL_ITHR_FINISHED      4


/* perl core threads */
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


/* From CPAN threads 1.11 */
typedef struct ithread_111_s {
    struct ithread_111_s *next;     /* Next thread in the list */
    struct ithread_111_s *prev;     /* Prev thread in the list */
    PerlInterpreter *interp;    /* The threads interpreter */
    PerlInterpreter *free_interp;
    UV tid;                     /* Threads module's thread id */
    perl_mutex mutex;           /* Mutex for updating things in this struct */
    UV count;                   /* How many SVs have a reference to us */
    int state;                  /* Detached, joined, finished, etc. */
    int gimme;                  /* Context of create */
    SV *init_function;          /* Code to run */
    SV *params;                 /* Args to pass function */
#ifdef WIN32
    DWORD  thr;                 /* OS's idea if thread id */
    HANDLE handle;              /* OS's waitable handle */
#else
    pthread_t thr;              /* OS's handle for the thread */
#endif
    UV stack_size;
} ithread2;



NV threads_version;   /* current used threads version */


#define state_is_joined(thread)    ithread_state_is_joined(aTHX_ thread)
#define state_is_finished(thread)  ithread_state_is_finished(aTHX_ thread)
#define state_is_detached(thread)  ithread_state_is_detached(aTHX_ thread)
#define state_is_running(thread)   ithread_state_is_running(aTHX_ thread)
#define state_is_joinable(thread)  ithread_state_is_joinable(aTHX_ thread)
#define state_in_context(thread)   ithread_state_in_context(aTHX_ thread)

#define ANOTHER_THREADS     threads_version > 1.09

#define ITHREAD_CORE        ((ithread*)thread)
#define ITHREAD_CPAN        ((ithread2*)thread)

#define ITHREAD_STATE_IS( state )               \
    (ANOTHER_THREADS ?                          \
          ithread2_state_is(aTHX_ sv, state)    \
        : ithread_state_is(aTHX_ sv, state)     \
    )                                           \



void* state_get_current_ithread (pTHX) {
    void*  thread;
    SV*    thr_sv;
    int    count;

    dSP;
    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSVpv("threads", 0)));
    PUTBACK;
    count = call_method("self", G_SCALAR);

    SPAGAIN;

    if (count != 1)
       croak("%s\n","Internal error, couldn't call thread->self");

    thr_sv = POPs;

    if (ANOTHER_THREADS) {
        thread = (void*)(INT2PTR(ithread2*, SvIV(SvRV(thr_sv))));
    }
    else {
        thread = (void*)(INT2PTR(ithread*, SvIV(SvRV(thr_sv))));
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return thread;
}


void* state_sv_to_ithread(pTHX_ SV *sv) {
    void* thread = !SvROK(sv) ? state_get_current_ithread(aTHX) :
                    ANOTHER_THREADS ?
                           (void*)INT2PTR(ithread2*, SvIV(SvRV(sv)))
                         : (void*)INT2PTR(ithread*, SvIV(SvRV(sv)))
    ;
    return thread;
}


int ithread_state_is (pTHX_ SV* sv, signed char state) {
    void*  thread = state_sv_to_ithread(aTHX_ sv);
    return (ITHREAD_CORE->state & state) ? 1 : 0;
}


int ithread2_state_is (pTHX_ SV* sv, int state) {
    void*  thread = state_sv_to_ithread(aTHX_ sv);
    return (ITHREAD_CPAN->state & state) ? 1 : 0;
}


int ithread_state_is_running (pTHX_ SV* sv) {
    return ! ITHREAD_STATE_IS(PERL_ITHR_FINISHED);
}


int ithread_state_is_finished (pTHX_ SV* sv) {
    return ITHREAD_STATE_IS( PERL_ITHR_FINISHED );
}


int ithread_state_is_detached (pTHX_ SV* sv) {
    return ITHREAD_STATE_IS( PERL_ITHR_DETACHED );
}


int ithread_state_is_joined (pTHX_ SV* sv) {
    return ITHREAD_STATE_IS( PERL_ITHR_JOINED );
}


int ithread_state_is_joinable (pTHX_ SV* sv) {
    void*  thread = state_sv_to_ithread(aTHX_ sv);

    if (ANOTHER_THREADS) {
        return (    !(ITHREAD_CPAN->state & PERL_ITHR_DETACHED)
                 && !(ITHREAD_CPAN->state & PERL_ITHR_JOINED)
               ) ? 1 : 0;
    }
    else {
        return (    !(ITHREAD_CORE->state & PERL_ITHR_DETACHED)
                 && !(ITHREAD_CORE->state & PERL_ITHR_JOINED)
               ) ? 1 : 0;
    }
}


SV* ithread_state_in_context (pTHX_ SV* sv) {
    void*  thread = state_sv_to_ithread(aTHX_ sv);
    int    gimme
              = ANOTHER_THREADS ? ITHREAD_CPAN->gimme
                                : ITHREAD_CORE->gimme
    ;

    return   gimme & G_VOID  ? &PL_sv_undef
           : gimme & G_ARRAY ? &PL_sv_yes
           : &PL_sv_no  // but this isn't G_SCALAR?
    ;
}


NV _get_threads_VERSION ( pTHX ) {
    int  count;
    SV*  sv;
    NV   ver;

    dSP;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSVpv("threads", 0)));
    PUTBACK;
    count = call_method("VERSION", G_SCALAR);

    SPAGAIN;

    if (count != 1)
       croak("Big trouble\n");

    sv = POPs;
    if (SvOK(sv) && looks_like_number(sv)) {
        ver = SvNV(sv);
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return ver;
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

SV*
state_in_context (obj)
	SV* obj

#endif /* USE_ITHREADS */

BOOT:
{
#ifdef USE_ITHREADS
    /* check threads VERSION for CPAN version */

    HV*  stash;
    stash = gv_stashpv("threads", 0);

    if (stash) {
        threads_version = _get_threads_VERSION(aTHX);
    }

    if (!threads_version) {
        croak("You must use threads before useing Thread::State.");
    }
#endif /* USE_ITHREADS */
}

