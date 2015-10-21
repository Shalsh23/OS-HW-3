/*BSD License

Copyright © belongs to the uploader, all rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice, with the name of the uploader, and this list of conditions;

Redistributions in binary form must reproduce the above copyright notice, with the name of the uploader, and this list of conditions in the documentation and/or other materials provided with the distribution;
Neither the name of the uploader nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
*/

// includes, system
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <assert.h>
#include <sys/time.h>
// includes, project
#include <cutil.h>
//#include "mycutil.h"

// includes, kernels
#include <parser_kernel.cu>
#include <hash_funcs.h>
#include <defs.h>
#include <list>
int *packet_start_token; // we need as many packets as the number of threads
int *send_tokens_count, *docs_count_arg;
int *packet_doc_map, *doc_size;
float *magnitude_array, *magnitude_res_array;
float *similarity_matrix, *similarity_res_matrix;

extern char cwd[1024];

extern std::list<char*> docs;
/********************************************************/
//MyHashMapElement **freq_packets_array_remote;
//MyHashMapElement **doc_token_hashtable_remote;  // each doc has its own token hash table
MyHashMapElement *occ_hash_table_remote;
int *token_doc_map_remote;
CalcFreqController  *token_division_controller_remote;
CalcFreqController  *token_division_controller_host;
float *doc_similarity_matrix_remote;
float *doc_similarity_matrix_host;
int *doc_rank_matrix_remote;
int *doc_rank_matrix_host;

struct timeval memcpy_start;
struct timeval memcpy_end;
struct timeval parser_start;
struct timeval parser_end;
struct timeval corpus_start;
struct timeval corpus_end;
struct timeval normalize_start;
struct timeval normalize_end;

void create_remote_hash_tables(MyHashMapElement **hash_doc_token_tables, MyHashMapElement **hash_doc_token_sub_tables, int docs_count, int *sub_table_size, int *table_size, int *occ_table_size);

void free_remote_hash_tables(MyHashMapElement **hash_doc_token_tables, MyHashMapElement **hash_doc_token_sub_tables, int docs_count);
void free_local_buffers();

struct timeval profile_start;
struct timeval profile_end;
struct timeval prep_start;
struct timeval prep_end;

long calcDiffTime(struct timeval* strtTime, struct timeval* endTime)
{
    return(
        endTime->tv_sec*1000000 + endTime->tv_usec
        - strtTime->tv_sec*1000000 - strtTime->tv_usec
        );
  
}


void load_parser_kernel(char *token_array, int tokens_count, int *doc_token_count, int docs_count)
{
    CUT_DEVICE_INIT(1, NULL);
    
    printf("Running kernel, cnt = %d \n", tokens_count);

    // allocate host memory for the string tokens
    char *host_local, *host_res;
    unsigned int *token_length_host;
    int *token_doc_map_local;
    host_local = token_array; //(char *)malloc(32*tokens_count*sizeof(char *));
    token_length_host = (unsigned int *)malloc(tokens_count*sizeof(unsigned int));
    token_doc_map_local = (int *)malloc(tokens_count * sizeof(int));
    token_division_controller_host = (CalcFreqController *)malloc(docs_count * sizeof(CalcFreqController));
    doc_similarity_matrix_host = (float *)malloc(docs_count * docs_count * sizeof(float));
    doc_rank_matrix_host = (int *)malloc(docs_count * docs_count * sizeof(int));
    int num_tokens = 0;
    for (int i = 0; i != docs_count; i++)
      {
        token_division_controller_host[i].doc_index = i;
        token_division_controller_host[i].doc_token_start = num_tokens;
        token_division_controller_host[i].doc_token_count = doc_token_count[i];
        num_tokens += doc_token_count[i];
        printf("token_start = %d, token_count = %d\n", token_division_controller_host[i].doc_token_start,
               token_division_controller_host[i].doc_token_count);
      }

    int remain_doc_tokens = doc_token_count[0];
    int cur_doc = 0;
    gettimeofday(&prep_start, NULL); 

    for(int i=0; i<tokens_count; i++)
    {
        int j;
		for(j=0; j<TOKEN_MAX_SIZE_PLUS_END; j++)
		{
            token_array[i * TOKEN_MAX_SIZE_PLUS_END + j] = token_array[i * TOKEN_MAX_SIZE_PLUS_END + j];
			if(token_array[i * TOKEN_MAX_SIZE_PLUS_END + j]=='\0')
				break;
		}
        
        token_length_host[i] = j;
        token_doc_map_local[i] = cur_doc;
        remain_doc_tokens--;
        if (remain_doc_tokens == 0){
          cur_doc++;
          if (i != tokens_count - 1)
            remain_doc_tokens = doc_token_count[cur_doc];
        }
	}
    assert(remain_doc_tokens == 0);
    assert(cur_doc == docs_count);

    gettimeofday(&prep_end, NULL); 
    long prep_time = calcDiffTime(&prep_start, &prep_end);
    printf("prep token time = %ld\n", prep_time);

	
	// allocate device memory
    char *dev_mem;
    CUDA_SAFE_CALL(cudaMalloc((void**) &dev_mem, 32*tokens_count*sizeof(char *)));
    unsigned int *token_length_array_mem;
    CUDA_SAFE_CALL(cudaMalloc((void**) &token_length_array_mem, tokens_count*sizeof(unsigned int)));
    CUDA_SAFE_CALL(cudaMalloc((void**) &token_doc_map_remote, tokens_count*sizeof(int)));
    CUDA_SAFE_CALL(cudaMalloc((void**) &token_division_controller_remote, docs_count*sizeof(CalcFreqController)));

    // copy host memory to device
     gettimeofday(&memcpy_start, NULL); 
    CUDA_SAFE_CALL(cudaMemcpy(dev_mem, host_local, 32*sizeof(char)*tokens_count, cudaMemcpyHostToDevice) );	
    CUDA_SAFE_CALL(cudaMemcpy(token_length_array_mem, token_length_host, sizeof(unsigned int)*tokens_count, cudaMemcpyHostToDevice) );	
    CUDA_SAFE_CALL(cudaMemcpy(token_doc_map_remote, token_doc_map_local, sizeof(int)*tokens_count, cudaMemcpyHostToDevice) );	
    CUDA_SAFE_CALL(cudaMemcpy(token_division_controller_remote, token_division_controller_host, sizeof(CalcFreqController)*docs_count, cudaMemcpyHostToDevice) );	
    gettimeofday(&memcpy_end, NULL); 
        long memcpytime = calcDiffTime(&memcpy_start, &memcpy_end);
    printf("memcpy = %ld\n", memcpytime);

    MyHashMapElement *hash_doc_token_sub_tables_host[MAX_GRID_SIZE];
    MyHashMapElement *hash_doc_token_tables_host[docs_count];
    int sub_table_size, table_size, occ_table_size;
    create_remote_hash_tables(hash_doc_token_tables_host, hash_doc_token_sub_tables_host, docs_count, &sub_table_size, &table_size, &occ_table_size);
    MyHashMapElement **hash_doc_token_sub_tables_remote;
    MyHashMapElement **hash_doc_token_tables_remote;
    CUDA_SAFE_CALL(cudaMalloc((void**) &hash_doc_token_sub_tables_remote, MAX_GRID_SIZE * sizeof(MyHashMapElement *)));
    CUDA_SAFE_CALL(cudaMalloc((void**) &hash_doc_token_tables_remote, docs_count * sizeof(MyHashMapElement *)));
    CUDA_SAFE_CALL(cudaMemcpy(hash_doc_token_sub_tables_remote, hash_doc_token_sub_tables_host, MAX_GRID_SIZE * sizeof(MyHashMapElement *), cudaMemcpyHostToDevice));	
    CUDA_SAFE_CALL(cudaMemcpy(hash_doc_token_tables_remote, hash_doc_token_tables_host, docs_count * sizeof(MyHashMapElement *), cudaMemcpyHostToDevice)); 


//    CUDA_SAFE_CALL(cudaMemcpy((send_tokens_count), &tokens_count, sizeof(int), cudaMemcpyHostToDevice) );
    
    // create and start timer
    unsigned int timer = 0;
    CUT_SAFE_CALL(cutCreateTimer(&timer));
    CUT_SAFE_CALL(cutStartTimer(timer));

    // setup execution parameters
    dim3 dimBlock(MAX_THREADS);
    dim3 dimGrid(docs_count); // TODO floor(tokens_count/(threads.x * 2)));


    gettimeofday(&profile_start, NULL); 

    gettimeofday(&parser_start, NULL); 
    StripAffixes<<< dimGrid, dimBlock >>>(dev_mem, token_length_array_mem, token_division_controller_remote); //send_tokens_count);
    dbg
      { 
        CUT_SAFE_CALL(cutStopTimer(timer));
        printf("\nStrip affixes time: %f (ms) n\n", cutGetTimerValue(timer));

        host_res = (char *)malloc(TOKEN_MAX_SIZE_PLUS_END * tokens_count * sizeof(char));
        CUDA_SAFE_CALL(cudaMemcpy(host_res, dev_mem, TOKEN_MAX_SIZE_PLUS_END*sizeof(char)*tokens_count, cudaMemcpyDeviceToHost) );
        CUDA_SAFE_CALL(cudaMemcpy(token_length_host, token_length_array_mem, sizeof(unsigned int)*tokens_count, cudaMemcpyDeviceToHost) );
        for(int i=0; i<tokens_count; i++)
    		{
    			for(int j=0; j<TOKEN_MAX_SIZE_PLUS_END; j++)
    			{
    				if(host_res[i*TOKEN_MAX_SIZE_PLUS_END+j]=='\0')
    					break;
    				//printf("%c",host_res[i*32+j]);
    			}
    			printf("\n%3d %s %s (%d %d)",i, &token_array[i * TOKEN_MAX_SIZE_PLUS_END], &host_res[i*TOKEN_MAX_SIZE_PLUS_END], token_length_host[i], token_doc_map_local[i]);
    		}
        CUT_SAFE_CALL(cutStartTimer(timer));
      }

    InitOccTable<<<OCC_HASH_TABLE_SIZE/32, 32>>>(occ_hash_table_remote);  // TODO make it multi-grid
    dimBlock.x = HASH_DOC_TOKEN_NUM_THREADS;
    for (int i = 0; i != docs_count;) // TODO we can do only one batch
      { 
        dimGrid.x = min(16, docs_count - i);  // TODO replace the magic number

        MakeDocHash<<< dimGrid, dimBlock >>>(dev_mem, token_length_array_mem, &token_division_controller_remote[i], hash_doc_token_sub_tables_remote, &hash_doc_token_tables_remote[i], sub_table_size, table_size);
        
        i += dimGrid.x;
      }
    gettimeofday(&parser_end, NULL); 
    long parsetime = calcDiffTime(&parser_start, &parser_end);
    printf("parsetime = %ld\n", parsetime);


    gettimeofday(&corpus_start, NULL); 
    assert(HASH_DOC_TOKEN_TABLE_SIZE % 32 == 0);
    AddToOccTable<<<HASH_DOC_TOKEN_TABLE_SIZE/32, 32>>>(hash_doc_token_tables_remote, occ_hash_table_remote, docs_count);
    gettimeofday(&corpus_end, NULL); 
    long corpustime = calcDiffTime(&corpus_start, &corpus_end);
    printf("corpustime = %ld\n", corpustime);

    dimBlock.x = HASH_DOC_TOKEN_TABLE_SIZE;
    dimGrid.x = docs_count;
    
    gettimeofday(&normalize_start, NULL); 
    float *bucket_sqrt_sum_remote;
    CUDA_SAFE_CALL(cudaMalloc((void**) &bucket_sqrt_sum_remote, docs_count * HASH_DOC_TOKEN_TABLE_SIZE * sizeof(float)));
    CalcTfIdf<<<dimGrid, dimBlock>>>(token_division_controller_remote, hash_doc_token_tables_remote, occ_hash_table_remote, docs_count, bucket_sqrt_sum_remote);

    dimBlock.x = 1;

    CalcTfIdf2<<<dimGrid, dimBlock>>>(token_division_controller_remote, hash_doc_token_tables_remote, occ_hash_table_remote, docs_count, bucket_sqrt_sum_remote);

    dimBlock.x = HASH_DOC_TOKEN_TABLE_SIZE;

    CalcTfIdf3<<<dimGrid, dimBlock>>>(token_division_controller_remote, hash_doc_token_tables_remote, occ_hash_table_remote, docs_count, bucket_sqrt_sum_remote);
    gettimeofday(&normalize_end, NULL); 
    long tfidftime = calcDiffTime(&normalize_start, &normalize_end);
    printf("tfidf = %ld\n", tfidftime);

    dimGrid.x = docs_count;    dimGrid.y = docs_count;
    dimBlock.x = HASH_DOC_TOKEN_TABLE_SIZE; 
    // each block does a pair similarity
    CalcSimilarities<<< dimGrid, dimBlock >>>(hash_doc_token_tables_remote, occ_hash_table_remote, doc_similarity_matrix_remote, docs_count);
    dimGrid.x = docs_count ;   dimGrid.y = 1;
    dimBlock.x = docs_count;
    SortSimilarities<<< dimGrid, dimBlock >>>(doc_similarity_matrix_remote, doc_rank_matrix_remote, docs_count);

    gettimeofday(&profile_end, NULL);
    long profile_time = calcDiffTime(&profile_start, &profile_end);
    printf("total kernel time = %ld\n", profile_time);

        //        CalcIDF
    dbg{
       CUT_SAFE_CALL(cutStopTimer(timer));
       printf("\nHash Doc table time: %f (ms) n\n", cutGetTimerValue(timer));
       for (int i = 0 ; i != 16; i++)
         printf("subtable %d address 0x%x\n", i, hash_doc_token_sub_tables_host[i]);

       //       CUDA_SAFE_CALL(cudaMemcpy(token_length_host, token_length_array_mem, sizeof(unsigned int)*tokens_count, cudaMemcpyDeviceToHost) );
       //       for (int i = 0; i != dimBlock.x; i++)
       //         printf("thread %d's sub table address = 0x%x.\n", i ,token_length_host[i]);

       MyHashMapElement *tables_host[docs_count];
       int doc = 39; if (doc < docs_count)//for (int doc = 39; doc != docs_count; doc+)
         {
           tables_host[doc] = (MyHashMapElement *)malloc(table_size * sizeof (MyHashMapElement));
           CUDA_SAFE_CALL(cudaMemcpy(tables_host[doc], hash_doc_token_tables_host[doc], table_size*sizeof(MyHashMapElement), cudaMemcpyDeviceToHost) );
           printf ("The %d'th docuemnt hash table:\n", doc);
           MyHashMapElement *table = tables_host[doc];
           for (int j = 0; j != HASH_DOC_TOKEN_TABLE_SIZE; j++)
             {
               printf("The %d'th document hash table, the %d'th bucket\n", doc, j);
               for (int ele = 0; ele != HASH_DOC_TOKEN_BUCKET_SIZE; ele++)
                 {
                   printf("count in bucket(%d), key(0x%x),freq(%d), tokenLen(%d),subkey(%d) tfidf(%f) \n", table[ele].countInBuc,
                          table[ele].key, table[ele].freq, table[ele].tokenLength, table[ele].subkey, table[ele].tfidf);
                 }
               table += HASH_DOC_TOKEN_BUCKET_SIZE;
             }

           free(tables_host[doc]);
         }
       MyHashMapElement *occ_table_host;
       occ_table_host = (MyHashMapElement *)malloc(occ_table_size * sizeof (MyHashMapElement));
       CUDA_SAFE_CALL(cudaMemcpy(occ_table_host, occ_hash_table_remote, occ_table_size*sizeof(MyHashMapElement), cudaMemcpyDeviceToHost) );
       printf("occurence table\n");
       for (int occ = 0; occ != OCC_HASH_TABLE_SIZE; occ++)
         {
           MyHashMapElement *bucket = &occ_table_host[occ * OCC_HASH_TABLE_BUCKET_SIZE];
           printf("occurrence table: the %d'th bucket:\n", occ);
           for (int ele = 0; ele != OCC_HASH_TABLE_BUCKET_SIZE; ele++)
             {
               printf("count in bucket(%d), key(0x%x),freq(%d), tokenLen(%d),subkey(%d) \n", bucket[ele].countInBuc,
                      bucket[ele].key, bucket[ele].freq, bucket[ele].tokenLength, bucket[ele].subkey);
             }
         }

    }
    CUDA_SAFE_CALL(cudaMemcpy(doc_similarity_matrix_host, doc_similarity_matrix_remote, docs_count * docs_count * sizeof(float), cudaMemcpyDeviceToHost));
    CUDA_SAFE_CALL(cudaMemcpy(doc_rank_matrix_host, doc_rank_matrix_remote, docs_count * docs_count * sizeof(int), cudaMemcpyDeviceToHost));    
    dbg {
      printf("similarity matrix: \n");
      for (int doc1 = 0; doc1 != docs_count; doc1++)
        {
          for (int doc2 = 0; doc2 != docs_count; doc2++)
            printf("%5f(%d) ", doc_similarity_matrix_host[doc1*docs_count + doc2], doc_rank_matrix_host[doc1*docs_count + doc2]);
          printf("\n");
        }
    }

    float *sim = doc_similarity_matrix_host;
    int *rank = doc_rank_matrix_host;
    std::list<char*>::const_iterator doc1i = docs.begin();
    for (int doc1 = 0; doc1 != docs_count; doc1++, doc1i++)
      {
        printf("\n%s : \n", &(*doc1i)[strlen(cwd)]);

        for (int r = 0; r != 10; r++)
          {
            int find = 0;
            std::list<char*>::const_iterator doc2i = docs.begin();
            for (int doc2 = 0; doc2 != docs_count; doc2++, doc2i++)
              {
                if (rank[doc1 * docs_count + doc2] == r)
                  {
                    printf("%5f, %s\n", sim[doc1 * docs_count + doc2], &(*doc2i)[strlen(cwd)]);
                    find = 1;
                  }
              }
            if (!find) break;
          }
      }
    

    CUT_CHECK_ERROR("Kernel execution failed");

	CUT_SAFE_CALL(cutDeleteTimer(timer));

    CUDA_SAFE_CALL(cudaFree(dev_mem));
    free_remote_hash_tables(hash_doc_token_tables_host, hash_doc_token_sub_tables_host, docs_count);
    free_local_buffers();    
    CUT_EXIT(0, 0);

}

void create_remote_hash_tables(MyHashMapElement **hash_doc_token_tables, MyHashMapElement **hash_doc_token_sub_tables, int docs_count, int *sub_table_size, int *table_size, int *occ_table_size)
{
  *sub_table_size = HASH_DOC_TOKEN_SUB_TABLE_SIZE*HASH_DOC_TOKEN_NUM_THREADS* HASH_DOC_TOKEN_BUCKET_SUB_SIZE;
  *table_size = HASH_DOC_TOKEN_TABLE_SIZE * HASH_DOC_TOKEN_BUCKET_SIZE;
  *occ_table_size = OCC_HASH_TABLE_SIZE * OCC_HASH_TABLE_BUCKET_SIZE;
  for (int i = 0; i != MAX_GRID_SIZE; i++)
    {
      CUDA_SAFE_CALL(cudaMalloc((void **)&hash_doc_token_sub_tables[i], (*sub_table_size)*sizeof(MyHashMapElement)));
    }
  for (int i = 0; i != docs_count; i++)
    {
      CUDA_SAFE_CALL(cudaMalloc((void **)&hash_doc_token_tables[i], (*table_size)*sizeof(MyHashMapElement)));
    }
  CUDA_SAFE_CALL(cudaMalloc((void **)&occ_hash_table_remote, (*occ_table_size) * sizeof(MyHashMapElement)));

  CUDA_SAFE_CALL(cudaMalloc((void **)&doc_similarity_matrix_remote, docs_count * docs_count * sizeof(float)));
  CUDA_SAFE_CALL(cudaMalloc((void **)&doc_rank_matrix_remote, docs_count * docs_count * sizeof(float)));

  printf("Allocating remote memory size = %d K bytes for hash_token_sub_tables\n", (*sub_table_size)*sizeof(MyHashMapElement) * docs_count/1024);
  printf("Allocating remote memory size = %d K bytes for hash_token_tables.\n", (*table_size)*sizeof(MyHashMapElement) * docs_count / 1024);
  printf("Allocating remote memory size = %d K bytes for global occurence table.\n", (*occ_table_size) * sizeof(MyHashMapElement)/1024);
}

void free_local_buffers()
{
  free(doc_similarity_matrix_host);
}

void free_remote_hash_tables(MyHashMapElement **hash_doc_token_tables, MyHashMapElement **hash_doc_token_sub_tables, int docs_count)
{
  for (int i = 0; i != MAX_GRID_SIZE; i++)
      CUDA_SAFE_CALL(cudaFree(hash_doc_token_sub_tables[i]));

  for (int i = 0; i != docs_count; i++)
    CUDA_SAFE_CALL(cudaFree(hash_doc_token_tables[i]));

  CUDA_SAFE_CALL(cudaFree(occ_hash_table_remote));
  CUDA_SAFE_CALL(cudaFree(doc_similarity_matrix_remote));
  CUDA_SAFE_CALL(cudaFree(doc_rank_matrix_remote));
}


