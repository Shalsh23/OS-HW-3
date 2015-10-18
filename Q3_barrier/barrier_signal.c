#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <pthread.h>

int n = 5;
int counter = 0;
pthread_t t[5];
pthread_mutex_t counter_lock;
struct sigaction act;

void sighandler(int signum, siginfo_t *info, void *ptr)
{
	printf("\n received signal %d\n", signum);
	exit(2);
}

barrier_wait()
{
	pthread_mutex_lock(&counter_lock);
	counter++;
	printf("\ncounter=%d\n",counter);
	pthread_mutex_unlock(&counter_lock);

	// int caught;
	// sigset_t sig;
	// sigemptyset(&sig);
	// sigaddset(&sig, SIGINT);

	if(counter != n)
	{
		for(;;)
		{
			// int s = sigwait(&sig, &caught);
			int s = sigaction(SIGINT, &act, NULL);

			if(s == 2)
			{
				printf("\ncaught the signal\n");
				fflush(stdout);
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
			printf("\nwaking up everyone\n");
			fflush(stdout);
			pthread_kill(t[j],SIGINT);	
		}
	}
	
	return;		
}

void *f()
{
	printf("\nentering f\n");
	barrier_wait();
	printf("barrier reached\n");
	return;
}


int main()
{
	

	pthread_mutex_init(&counter_lock, NULL);

	memset(&act, 0, sizeof(act));
	act.sa_sigaction = sighandler;
	act.sa_flags = SA_SIGINFO;

	// sigset_t set;
	// sigemptyset(&set);
	// sigaddset(&set, SIGINT);
	// pthread_sigmask(SIG_BLOCK, &set, NULL);

	int i;
	for(i=0; i<n; i++)
	{
		pthread_create(&t[i], NULL, f, NULL);
	}
	

	for(i=0; i<n; i++)
	{
		pthread_join(t[i], NULL);
	}

	printf("\n threads joined \n");

	return 0;
}