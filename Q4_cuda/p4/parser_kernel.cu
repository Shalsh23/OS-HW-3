/*BSD License

Copyright © belongs to the uploader, all rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice, with the name of the uploader, and this list of conditions;

Redistributions in binary form must reproduce the above copyright notice, with the name of the uploader, and this list of conditions in the documentation and/or other materials provided with the distribution;
Neither the name of the uploader nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
*/

#ifndef _PARSER_KERNEL_H_
#define _PARSER_KERNEL_H_

#include <stdio.h>
#include <string.h>
#include "string_funcs.cu"
#include "hash_funcs.cu"
#include "defs.h"


__device__ bool stripPrefixes ( char *str);

__device__ char prefixes[][16]= { "kilo", "micro", "milli", "intra", "ultra", "mega", "nano", "pico", "pseudo"};

__device__ char suffixes2[][2][16] = { { "ational", "ate" },
            { "tional",  "tion" },
            { "enci",    "ence" },
            { "anci",    "ance" },
            { "izer",    "ize" },
            { "iser",    "ize" },
            { "abli",    "able" },
            { "alli",    "al" },
            { "entli",   "ent" },
            { "eli",     "e" },
            { "ousli",   "ous" },
            { "ization", "ize" },
            { "isation", "ize" },
            { "ation",   "ate" },
            { "ator",    "ate" },
            { "alism",   "al" },
            { "iveness", "ive" },
            { "fulness", "ful" },
            { "ousness", "ous" },
            { "aliti",   "al" },
            { "iviti",   "ive" },
            { "biliti",  "ble" }};

__device__ char suffixes3[][2][16] = { { "icate", "ic" },
            { "ative", "" },
            { "alize", "al" },
            { "alise", "al" },
            { "iciti", "ic" },
            { "ical",  "ic" },
            { "ful",   "" },
            { "ness",  "" }};
            
__device__ char suffixes4[][16] = { "al",
            "ance",
            "ence",
            "er",
            "ic",
            "able", "ible", "ant", "ement", "ment", "ent", "sion", "tion",
            "ou", "ism", "ate", "iti", "ous", "ive", "ize", "ise"};


__device__ bool step1(char *str ) {

    char stem[32];
    bool changed = false;
    if ( str[strLen(str)-1] == 's' ) {
        if ( (hasSuffix( str, "sses", stem ))
                || (hasSuffix( str, "ies", stem)) ){
            str[strLen(str)-2] = '\0';
            changed = true;
        }
        else {
            if ( ( strLen(str) == 1 )
                    && ( str[strLen(str)-1] == 's' ) ) {
                str[0] = '\0';
                return true;
            }
            if ( str[strLen(str)-2 ] != 's' ) {
                str[strLen(str)-1] = '\0';
                changed = true;
            }
        }
    }

    if ( hasSuffix( str,"eed",stem ) ) {
        if ( measure( stem ) > 0 ) {
            str[strLen(str)-1] = '\0';
            changed = true;
        }
    }
    else {
        if (  (hasSuffix( str,"ed",stem ))
                || (hasSuffix( str,"ing",stem )) ) {
            if (containsVowel( stem ))  {

                if(stem[0]=='\0')
                  {
					str[0]='\0';
                    changed = true;
                  }
				else
                  {
					str[strLen(stem)] = '\0';
                    changed = true;
                  }
                if ( strLen(str) == 1 )
                    return changed;

                if ( ( hasSuffix( str,"at",stem) )
                        || ( hasSuffix( str,"bl",stem ) )
                        || ( hasSuffix( str,"iz",stem) ) ) {
                    int len = strLen(str);
                    str[len-1] = 'e';
                    str[len] = '\0';
                    changed = true;

                }
                else {
                    int length = strLen(str);
                    if ( (str[length-1] == str[length-2])
                            && (str[length-1] != 'l')
                            && (str[length-1] != 's')
                            && (str[length-1] != 'z') ) {
                        str[length-1]='\0';
                        changed = true;
                    }
                    else
                    if ( measure( str ) == 1 ) {
                        if ( cvc(str) )
                        {
                           str[length-1]='e';
                           str[length]='\0';
                           changed = true;
                        }   
                    }
                }
            }
        }
    }

    if ( hasSuffix(str,"y",stem) )
        if ( containsVowel( stem ) ) {
            int len = strLen(str);
            str[len-1]='i';
            str[len]='\0';
            changed = true;
        }
    return changed;
}

__device__ bool step2( char *str ) {
    
    char stem[32];
    int last = sizeof(suffixes2)/(sizeof(char)*2*16); //strange way of calculating length of array
    bool changed = false;

    for ( int index = 0 ; index < last; index++ ) {
        if ( hasSuffix ( str, suffixes2[index][0], stem ) ) {
            if ( measure ( stem ) > 0 ) {
                int stemlen, suffixlen, j;
                stemlen = strLen(stem);
                suffixlen = strLen(suffixes2[index][1]);
                changed = true;
                for(j=0; j<suffixlen; j++)
					str[stemlen+j] = suffixes2[index][1][j];
				str[stemlen+j] = '\0';
            }
        }
    }
    return changed;
}

__device__ bool step3( char *str ) {

    char stem[32];
    int last = sizeof(suffixes3)/(sizeof(char)*2*16); //strange way of calculating length of array/    
    bool changed= false;
    for ( int index = 0 ; index<last; index++ ) {
        if ( hasSuffix ( str, suffixes3[index][0], stem ))
            if ( measure ( stem ) > 0 ) {
                int stemlen, suffixlen, j;
                stemlen = strLen(stem);
                suffixlen = strLen(suffixes3[index][1]);
                changed = true;
                for( j=0; j<suffixlen; j++)
					str[stemlen+j] = suffixes3[index][1][j];
				str[stemlen+j] = '\0';
            }
    }
    return changed ;  
}

__device__ bool step4( char *str ) {

    char stem[32];
    int last = sizeof(suffixes4)/(sizeof(char)*16); //strange way of calculating length of array
    bool changed = false;
    for ( int index = 0 ; index<last; index++ ) {
        if ( hasSuffix ( str, suffixes4[index], stem ) ) {
            changed = true;
            if ( measure ( stem ) > 1 ) {
                str[strLen(stem)] = '\0';
            }
        }
    }
    return changed;
}

__device__ bool step5( char *str ) {

  bool changed = false;
    if ( str[strLen(str)-1] == 'e' ) {
        if ( measure(str) > 1 ) {
            str[strLen(str)-1] = '\0';
            changed = true;
        }
        else
        if ( measure(str) == 1 ) {
            char stem[32];
            int i;
            for ( i=0; i<strLen(str)-1; i++ )
                stem[i] = str[i];
            stem[i] = '\0';

            if ( !cvc(stem) ){
                str[strLen(str)-1] = '\0';
                changed = true;
            }
        }
    }

    if ( strLen(str) == 1 )
        return true;
    if ( (str[strLen(str)-1] == 'l')
            && (str[strLen(str)-2] == 'l') && (measure(str) > 1) )
        if ( measure(str) > 1 ) {
            str[strLen(str)-1] = '\0';
            changed = true;
        }
        
    return changed;
}



__device__ bool stripSuffixes(char *str ) {

  bool changed = false;
    changed = step1( str );
    if ( strLen(str) >= 1 )
        changed |= step2( str );
    if ( strLen(str) >= 1 )
        changed |= step3( str );
    if ( strLen(str) >= 1 )
        changed |= step4( str );
    if ( strLen(str) >= 1 )
        changed |= step5( str );
    return changed;
}

__device__ bool stripPrefixes ( char *str) {

    int  newLen, j;
    bool found = false;

    int last = sizeof(prefixes)/(sizeof(char)*16); //strange way of calculating length of array
    for ( int i=0 ; i<last; i++ ) 
    {
        //Find if str starts with prefix prefixes[i]
        found = prefixFind(str, prefixes[i]);
        if (found)
        {
            newLen = strLen(str) - strLen(prefixes[i]);
            for (j=0 ; j < newLen; j++ )
                str[j] = str[j+strLen(prefixes[i])];
            str[j] = '\0';
        }
    }
    return found;
}


__global__ void
StripAffixes(char *dev_res, unsigned int *token_length, CalcFreqController *controller)
{
     // add __shared__ for operations in str in loop below
     // adjust the token and token_length array pointer according to controller 
    char *base = &dev_res[controller[blockIdx.x].doc_token_start * TOKEN_MAX_SIZE_PLUS_END];
    unsigned int *token_length_base = &token_length[controller[blockIdx.x].doc_token_start];

    int tokens_count = controller[blockIdx.x].doc_token_count;
  	int step_count = tokens_count/blockDim.x;
    int remain = tokens_count - step_count * blockDim.x;
    int index = threadIdx.x *  TOKEN_MAX_SIZE_PLUS_END;
    if (threadIdx.x < remain )
      step_count += 1;

    __shared__ int *str[MAX_THREADS];
    int step_size = blockDim.x * TOKEN_MAX_SIZE_PLUS_END;

    for(int i=0; i< step_count; i++, index+=step_size) {
      str[threadIdx.x] = (int *)&base[index];
      bool changed = ToLowerCase( (char *)str[threadIdx.x]);
      changed |= Clean( (char *)str[threadIdx.x]);
      changed |= stripPrefixes((char *)str[threadIdx.x]);
      changed |= stripSuffixes((char *)str[threadIdx.x]);
      if (changed){
        token_length_base[index/TOKEN_MAX_SIZE_PLUS_END] = strLen((char *)str[threadIdx.x]);
      }	
    }
    return;
}

__global__ void 
InitOccTable(MyHashMapElement *occ_hash_table)
{
  MyHashMapElement *bucket = &occ_hash_table[((blockIdx.x * blockDim.x ) + threadIdx.x) * OCC_HASH_TABLE_BUCKET_SIZE];
  bucket->countInBuc = 0;
  dbg{
    bucket->key = 0xDEADBEEF;
    bucket->freq = 0;
    bucket->tokenLength = 0;
    bucket->subkey = 0;
    for (int j = 1; j < OCC_HASH_TABLE_BUCKET_SIZE; j++)
      {
        bucket[j].countInBuc = 0; 
        bucket[j].key = 0xDEADBEEF;
        bucket[j].freq = 0;
        bucket[j].tokenLength = 0;
        bucket[j].subkey = 0;
      }
  }
}

__global__ void
MakeDocHash(char *dev_mem, unsigned int *token_length, CalcFreqController *controller, 
         MyHashMapElement **hash_doc_token_sub_tables, MyHashMapElement **hash_doc_token_tables, int sub_table_size, int table_size)
{
    char *token_base = &dev_mem[controller[blockIdx.x].doc_token_start * TOKEN_MAX_SIZE_PLUS_END];
    unsigned int *token_length_base = &token_length[controller[blockIdx.x].doc_token_start];
    MyHashMapElement *hash_doc_token_sub_table = hash_doc_token_sub_tables[blockIdx.x];
    MyHashMapElement *hash_doc_token_table = hash_doc_token_tables[blockIdx.x];
    hash_doc_token_sub_table += sub_table_size * threadIdx.x / HASH_DOC_TOKEN_NUM_THREADS;
 
    {// clear the doc hash sub table in each thread
      initHashTable(hash_doc_token_sub_table, HASH_DOC_TOKEN_SUB_TABLE_SIZE, HASH_DOC_TOKEN_BUCKET_SUB_SIZE);
   
      // clear the doc hash table
      int bucketsPerThread = HASH_DOC_TOKEN_TABLE_SIZE / blockDim.x;
      if (threadIdx.x < HASH_DOC_TOKEN_TABLE_SIZE % blockDim.x)
        bucketsPerThread += 1;
      
      MyHashMapElement *bucket = &hash_doc_token_table[threadIdx.x * HASH_DOC_TOKEN_BUCKET_SIZE ];
      for (int i = 0; i != bucketsPerThread; i++)
        {
          bucket->countInBuc = 0;
          dbg{
            bucket->key = 0xDEADBEEF;
            bucket->subkey = 0;
            bucket->freq = 0;
            bucket->tokenLength = 0;
            for (int j = 1; j != HASH_DOC_TOKEN_BUCKET_SIZE; j++)
              {
                bucket[j].countInBuc = 0;
                bucket[j].key = 0xDEADBEEF;
                bucket[j].subkey = 0;
                bucket[j].freq = j;
                bucket[j].tokenLength = 0;
              }
          }
          bucket += blockDim.x * HASH_DOC_TOKEN_BUCKET_SIZE;
        }
    }

    int tokens_count = controller[blockIdx.x].doc_token_count;
  	int step_count = tokens_count/blockDim.x;
    int remain = tokens_count - step_count * blockDim.x;
    int index = threadIdx.x *  TOKEN_MAX_SIZE_PLUS_END;
    if (threadIdx.x < remain )
      step_count += 1;

    //    int *str;
    int step_size = blockDim.x * TOKEN_MAX_SIZE_PLUS_END;

	for(int i=0; i< step_count; i++, index+=step_size)
	{
      unsigned long key  = computeHash(&token_base[index]);
      insertElement(hash_doc_token_sub_table, key, HASH_DOC_TOKEN_SUB_TABLE_SIZE_LOG2, HASH_DOC_TOKEN_BUCKET_SUB_SIZE, token_length_base[index/TOKEN_MAX_SIZE_PLUS_END], 1);
    }

    __syncthreads();  // sub table construction is done

    // merge sub tables into one doc hash table
    hash_doc_token_sub_table = hash_doc_token_sub_tables[blockIdx.x];
    hash_doc_token_sub_table += threadIdx.x * HASH_DOC_TOKEN_BUCKET_SUB_SIZE;
    for (int i = 0; i != HASH_DOC_TOKEN_NUM_THREADS; i++)
      {
        MyHashMapElement *bucket = hash_doc_token_sub_table;
        int numInBucket = bucket->countInBuc;
        while(numInBucket--)
          {
            unsigned long key = bucket->key;
            insertElement(hash_doc_token_table, key, HASH_DOC_TOKEN_TABLE_SIZE_LOG2, HASH_DOC_TOKEN_BUCKET_SIZE, bucket->tokenLength, bucket->freq);
            bucket++;
          }
        hash_doc_token_sub_table += HASH_DOC_TOKEN_SUB_TABLE_SIZE * HASH_DOC_TOKEN_BUCKET_SUB_SIZE;
      }
  
  return;
}

__global__ void
AddToOccTable(MyHashMapElement **hash_doc_token_tables, MyHashMapElement *occ_hash_table, int numDocs)
{
  for (int i = 0; i != numDocs; i++)
    {
      MyHashMapElement *hash_doc_token_table = hash_doc_token_tables[i];
      MyHashMapElement *bucket = &hash_doc_token_table[(blockIdx.x * blockDim.x + threadIdx.x) * HASH_DOC_TOKEN_BUCKET_SIZE];
      int numInBucket = bucket->countInBuc;
      while (numInBucket--)
        {
          unsigned long key = bucket->key;
          insertElement(occ_hash_table, key, OCC_HASH_TABLE_SIZE_LOG2, OCC_HASH_TABLE_BUCKET_SIZE, bucket->tokenLength, 1);
          bucket++;
        }
    }
}

__global__ void 
CalcTfIdf(CalcFreqController *controller,  MyHashMapElement **hash_doc_token_tables, MyHashMapElement *occ_hash_table, int docs_count, float *bucket_sqrt_sum)
{
  // add __shared__ for bucket_sqrt_sum within one block
  int token_doc_count = controller[blockIdx.x].doc_token_count;
  int sumindex = blockIdx.x * HASH_DOC_TOKEN_TABLE_SIZE + threadIdx.x;
  // 1. calculate the un-normalized tfidf
  MyHashMapElement *bucket = hash_doc_token_tables[blockIdx.x];
  bucket += threadIdx.x * HASH_DOC_TOKEN_BUCKET_SIZE;
  int numInBucket = bucket->countInBuc;
  float bucketSqrtSum = 0.0f;
  while (numInBucket--)
    {
      unsigned long key = bucket->key;
      int occ = findElement(occ_hash_table, key, OCC_HASH_TABLE_SIZE_LOG2, OCC_HASH_TABLE_BUCKET_SIZE, bucket->tokenLength);
      if (occ != 0)  // we should be able to find it in the occ table
        {
          float tf = (float)bucket->freq/token_doc_count;
          float idf = log(float(docs_count)/occ);
          bucket->tfidf = tf * idf;
          bucketSqrtSum += bucket->tfidf * bucket->tfidf;
          dbg {
            bucket->subkey = occ;
          }
        }
      bucket++;
    }
  bucket_sqrt_sum[sumindex] = bucketSqrtSum;
}

__global__ void 
CalcTfIdf2(CalcFreqController *controller,  MyHashMapElement **hash_doc_token_tables, MyHashMapElement *occ_hash_table, int docs_count, float *bucket_sqrt_sum)
{
  // merge with CalcTfIdf(), use local reduction, add __syncthreads() where needed (and only there)
  int sumindex = blockIdx.x * HASH_DOC_TOKEN_TABLE_SIZE;
  float sum = 0.0f;
    int i;
    for (i = 0; i < HASH_DOC_TOKEN_TABLE_SIZE; i++)
      sum += bucket_sqrt_sum[sumindex + i];
    bucket_sqrt_sum[sumindex] = sqrt(sum);
}

__global__ void 
CalcTfIdf3(CalcFreqController *controller,  MyHashMapElement **hash_doc_token_tables, MyHashMapElement *occ_hash_table, int docs_count, float *bucket_sqrt_sum)
{
  // merge with CalcTfIdf()
  MyHashMapElement *bucket;
  int numInBucket;
  // 3. normalize
  float magnitude = bucket_sqrt_sum[blockIdx.x * HASH_DOC_TOKEN_TABLE_SIZE];
  bucket = hash_doc_token_tables[blockIdx.x];
  bucket += threadIdx.x * HASH_DOC_TOKEN_BUCKET_SIZE;
  numInBucket = bucket->countInBuc;
  while (numInBucket--)
    {
      float tfidf = (float)bucket->tfidf;
      tfidf = tfidf / magnitude;
      bucket->tfidf = tfidf;
      bucket++;
    }
}

__global__ void
CalcSimilarities(MyHashMapElement **hash_doc_token_tables, MyHashMapElement *occ_hash_table_remote, float *similarity_matrix, int docs_count)
{
  //  add __shared__ for similarity over all tokens in one doc, use reduction to write into similarity_matrix in 2nd loop
  MyHashMapElement *hashDoc_token_table1 = hash_doc_token_tables[blockIdx.x]; 
  MyHashMapElement *hashDoc_token_table2 = hash_doc_token_tables[blockIdx.y]; 
  float sim_sum = 0.0f;
  MyHashMapElement *bucket1 = hashDoc_token_table1 + threadIdx.x * HASH_DOC_TOKEN_BUCKET_SIZE;

  int num_ele_1 = bucket1->countInBuc;
  while (num_ele_1--)
    {
      MyHashMapElement *bucket2 = hashDoc_token_table2 + threadIdx.x * HASH_DOC_TOKEN_BUCKET_SIZE;
      int num_ele_2 = bucket2->countInBuc;
      int find = 0;
      while (num_ele_2--)
        {
          if ((bucket2->key == bucket1->key) && (bucket2->tokenLength == bucket1->tokenLength))
            {
              find = 1;
              break;
            }
          bucket2++;
        }
      if (find)
        sim_sum += bucket1->tfidf * bucket2->tfidf;

      bucket1++;
    }

    // 2nd loop
    if (threadIdx.x == 0)
      similarity_matrix[docs_count * blockIdx.x + blockIdx.y] = sim_sum;
    int i;
    for (i = 1; i < HASH_DOC_TOKEN_TABLE_SIZE; i++) {
      __syncthreads();
      if (threadIdx.x == i)
        similarity_matrix[docs_count * blockIdx.x + blockIdx.y] += sim_sum;
    }
}

/* This is only OK for small number of documents
 It returns the position of each entry in sorted pattern.
 On the host, extra work needs to be done to search for intended position. 
 TODO make it faster for large number of documents
*/
__global__ void
SortSimilarities(float *similarity_matrix, int *rank_matrix, int docs_count)
{
  __shared__ float similarity[512];   // TODO max docs count?
  float *sim_base = &similarity_matrix[blockIdx.x * docs_count];
  similarity[threadIdx.x] = sim_base[threadIdx.x];
  __syncthreads();
  
  float my_value = similarity[threadIdx.x];
  int myRank = 0;
  for (int i = 0; i != docs_count; i++)
    {
      if (i == threadIdx.x) 
        continue;
      if (similarity[i] > my_value) 
        myRank++;
    }

  rank_matrix[blockIdx.x * docs_count + threadIdx.x] = myRank;
}

#endif // #ifndef _PARSER_KERNEL_H_

