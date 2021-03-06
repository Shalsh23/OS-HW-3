#define CUDA_SAFE_CALL(call)                                               
do {                                                                  
  cudaError_t err = call;                                           
  if (cudaSuccess != err) {                                         
    fprintf (stderr, "Cuda error in file '%s' in line %i : %s.", 
	     __FILE__, __LINE__, cudaGetErrorString(err) );       
    exit(EXIT_FAILURE);                                          
  }                                                                
 } while (0)

