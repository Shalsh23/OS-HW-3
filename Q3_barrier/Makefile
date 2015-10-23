CC=gcc
CFLAGS = -c -Wall
TEST_FILE1 = barrier_test.c

all:barrier_signal.o $(TEST_FILE1)
	$(CC) -g -pthread $(TEST_FILE1) barrier_signal.o -o barrier_test

barrier_signal.o:barrier.h barrier_signal.c 
	gcc -c -pthread -Wall barrier_signal.c

clean:
	rm -rf *.o barriertest *~