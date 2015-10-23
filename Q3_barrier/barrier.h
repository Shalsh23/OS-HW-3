#ifndef BARRIER_H
#define BARRIER_H

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <pthread.h>

extern pthread_t *t; //array of tid
extern int *sigrecieved;
extern 	int n; 

typedef struct mythread_barrier
{
	int counter; 
	// pthread_t *t;
	pthread_mutex_t counter_lock;
	struct sigaction act;
	// int *sigrecieved;
} mythread_barrier_t;

typedef struct mythread_barrierattr
{

} mythread_barrierattr_t;

extern void mythread_barrier_init(mythread_barrier_t* pbarrier, mythread_barrierattr_t* pattr, unsigned count);
extern void mythread_barrier_wait(mythread_barrier_t* pbarrier);
extern void mythread_barrier_destroy(mythread_barrier_t* pbarrier);

#endif

