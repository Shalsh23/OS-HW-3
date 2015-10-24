#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <pthread.h>
#include "barrier.h"

// #define MAX 5 //Max number of threads calling barrier

pthread_t *t; //array of tid
int *sigrecieved;
int n;
int t_id = 0;

void sighandler(int signum, siginfo_t *info, void *ptr);


void mythread_barrier_init(mythread_barrier_t* pbarrier, mythread_barrierattr_t* pattr, unsigned count)
{
	n = count;
	pbarrier->counter = 0;
	t = (pthread_t*)malloc(sizeof(pthread_t)*count);
	pthread_mutex_init(&(pbarrier->counter_lock),NULL);
	memset(&(pbarrier->act), 0, sizeof(pbarrier->act));
	pbarrier->act.sa_sigaction = sighandler;
	pbarrier->act.sa_flags = SA_SIGINFO;
	sigrecieved = (int*)malloc(sizeof(int)*count);

	return;
}

void sighandler(int signum, siginfo_t *info, void *ptr)
{
	// printf("\n received signal %d\n", signum); fflush(stdout);
	pthread_t id = pthread_self();
	int i,j;
	for(i=0; i<n; i++)
	{//printf("in loop"); fflush(stdout);
		if(t[i] == id)
			j = i;
	}
	sigrecieved[j] = 1;
	// printf("set flag");fflush(stdout);
	return;
}

void mythread_barrier_wait(mythread_barrier_t* pbarrier)
{
	pthread_mutex_lock(&(pbarrier->counter_lock));
	pbarrier->counter++;
	// printf("\ncounter=%d\n",pbarrier->counter);
	pthread_mutex_unlock(&(pbarrier->counter_lock));

	pthread_t curr_tid = pthread_self();
	// int k;

	int i,k, flag = 0;

	for(i=0; i<n; i++)
	{
		if(t[i] == curr_tid)
			flag = 1;
	}
	
	if(flag != 1)
	{
		pthread_mutex_lock(&(pbarrier->counter_lock));
		t[t_id] = curr_tid;
		// k = t_id;
		t_id++;
		pthread_mutex_unlock(&(pbarrier->counter_lock));		
	}

	
	
	for(i=0; i<n; i++)
	{
		if(t[i] == curr_tid)
			k = i;
	}


	// int caught;
	// sigset_t sig;
	// sigemptyset(&sig);
	// sigaddset(&sig, SIGINT);

	if(pbarrier->counter != n)
	{
		for(;;)
		{
			// int s = sigwait(&sig, &caught);
			int s = sigaction(SIGUSR2, &(pbarrier->act), NULL);

			if(sigrecieved[k]==1)
			{
				// printf("\ncaught the signal\n");
				// fflush(stdout);

				//reset the flag
				sigrecieved[k] = 0;

				break;
			}
				
		}
	}
	else
	{
		//send signals to all threads waiting on this
		int j;
		for(j = 0; j < n; j++)
		{			
			if(j==k)
				continue;
			// printf("\nwaking up everyone\n");
			fflush(stdout);
			pthread_kill(t[j],SIGUSR2);	
		}
		if(sigrecieved[k]==1)
			sigrecieved[k] = 0;
		//reset the counter variable
			pbarrier->counter = 0;
	}
	
	return;		
}

void mythread_barrier_destroy(mythread_barrier_t* pbarrier)
{
	return;
}



