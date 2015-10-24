#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <pthread.h>
#include "barrier.h"

mythread_barrier_t b;
pthread_t *t;

void *f()
{
	// printf("\nentering f\n");fflush(stdout);
	mythread_barrier_wait(&b);
	// printf("barrier reached\n");fflush(stdout);
	mythread_barrier_wait(&b);
	// printf("\nbarrier reached 2\n");fflush(stdout);
	return;
}

int main()
{
	

	// pthread_mutex_init(&counter_lock, NULL);

	// memset(&act, 0, sizeof(act));
	// act.sa_sigaction = sighandler;
	// act.sa_flags = SA_SIGINFO;

	// sigset_t set;
	// sigemptyset(&set);
	// sigaddset(&set, SIGINT);
	// pthread_sigmask(SIG_BLOCK, &set, NULL);
	int n = 2;
	pthread_t t[n];
	mythread_barrier_init(&b,NULL,n);
	// printf("\n creating thread \n");
	int i;
	for(i=0; i<n; i++)
	{
		pthread_create(&t[i], NULL, f, NULL);
	}
	
	// printf("joining threads\n");
	for(i=0; i<n; i++)
	{
		pthread_join(t[i], NULL);
	}

	mythread_barrier_destroy(&b);

	// printf("\n threads joined \n");fflush(stdout);

	return 0;
}