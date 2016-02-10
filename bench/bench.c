#include <stdio.h>
#include <stdlib.h>
#include "mpir.h"
#define SIZE_OF_STAT 50
#define INNER_ITER 200
#define BOUND_OF_LOOP 1
#define MAX_LIMBS 1000
#define INCREMENT 7
define(`callfunc',`
        ifdef(`rps',`  ret = funcname (data1, limbs); ') //TODO could maybe use ifelse based switch here which might look nicer
        ifdef(`ps',`   funcname (data1, limbs); ')
        ifdef(`rpps',` ret =  funcname (data1, data2, limbs); ')
        ifdef(`pps',`  funcname (data1, data2, limbs); ')
        ifdef(`ppps',` funcname (data1, data2, data3, limbs); ')
        ifdef(`pppps',`funcname (data1, data2, data3, data4, limbs); ')
    ')

void inline
Filltimes(mp_limb_t **times, mp_ptr data1, mp_ptr data2, mp_ptr data3, mp_ptr data4,
    mp_ptr sdata1, mp_ptr sdata2, mp_ptr sdata3, mp_ptr sdata4, mp_size_t limbs) {
  unsigned long flags;
  long ret;
  int i, j, k;
  mp_limb_t start, end;
  unsigned cycles_low, cycles_high, cycles_low1, cycles_high1;
  volatile int variable = 0;
  gmp_randstate_t rand;

  gmp_randinit_default(rand);
  asm volatile ("CPUID\n\t"
      "RDTSC\n\t"
      "mov %%edx, %0\n\t"
      "mov %%eax, %1\n\t": "=r" (cycles_high), "=r" (cycles_low)::
      "%rax",
      "%rbx",
      "%rcx",
      "%rdx");
  asm volatile ( "RDTSCP\n\t"
      "mov %%edx, %0\n\t"
      "mov %%eax, %1\n\t"
      "CPUID\n\t"
      : "=r" (cycles_high), "=r" (cycles_low)::
      "%rax", "%rbx", "%rcx", "%rdx");
  asm volatile ("CPUID\n\t"
      "RDTSC\n\t"
      "mov %%edx, %0\n\t"
      "mov %%eax, %1\n\t": "=r" (cycles_high), "=r" (cycles_low)::
      "%rax",
      "%rbx",
      "%rcx",
      "%rdx");
  asm volatile ( "RDTSCP\n\t"
      "mov %%edx, %0\n\t"
      "mov %%eax, %1\n\t"
      "CPUID\n\t"
      : "=r" (cycles_high), "=r" (cycles_low)::
      "%rax", "%rbx", "%rcx", "%rdx");
  for (j=0; j<BOUND_OF_LOOP; j++)
  {
    gmp_randseed_ui(rand, j);
    mpn_randomb(sdata1, rand, limbs);
    mpn_randomb(sdata2, rand, limbs);
    mpn_randomb(sdata3, rand, limbs);
    mpn_randomb(sdata4, rand, limbs);
    mpn_copyi(data1, sdata1, limbs);
    mpn_copyi(data2, sdata2, limbs);
    mpn_copyi(data3, sdata3, limbs);
    mpn_copyi(data4, sdata4, limbs);

    for (k = 0; k < INNER_ITER; k++)
    {
      callfunc
    }

    for (i = 0; i< SIZE_OF_STAT; i++)
    {
      mpn_copyi(data1, sdata1, limbs);
      mpn_copyi(data2, sdata2, limbs);
      mpn_copyi(data3, sdata3, limbs);
      mpn_copyi(data4, sdata4, limbs);
      variable = 0;

      for (k = 0; k < INNER_ITER; k++)
      {
        callfunc
      }

      // start timing
      asm volatile (
          "CPUID\n\t"
          "RDTSC\n\t"
          "mov %%edx, %0\n\t"
          "mov %%eax, %1\n\t": "=r" (cycles_high), "=r"
          (cycles_low):: "%rax", "%rbx", "%rcx", "%rdx");

      for (k = 0; k < INNER_ITER; k++)
      {
        callfunc
      }

      // end timing
      asm volatile(
          "RDTSCP\n\t"
          "mov %%edx, %0\n\t"
          "mov %%eax, %1\n\t": "=r" (cycles_high1), "=r"
          "CPUID\n\t"
          (cycles_low1):: "%rax", "%rbx", "%rcx", "%rdx");

      start = ( ((mp_limb_t)cycles_high << 32) | cycles_low );
      end = ( ((mp_limb_t)cycles_high1 << 32) | cycles_low1 );
      if ( (end - start) < 0) {
        printf("ERROR IN TAKING THE TIME!!!!!!\n loop(%d) stat(%d) start = %ld, end = %ld, variable = %u\n", j, i, start, end, variable);
        times[j][i] = 0;
      }
      else
      {
        times[j][i] = (end - start)/INNER_ITER;
      }
    }
  }

  gmp_randclear(rand);
  return;
}

mp_limb_t var_calc(mp_limb_t *inputs, int
    size)
{
  int i;
  mp_limb_t acc = 0, previous = 0, temp_var = 0;
  for (i=0; i< size; i++) {
    if (acc < previous) goto overflow;
    previous = acc;
    acc += inputs[i];
  }
  acc = acc * acc;
  if (acc < previous) goto overflow;
  previous = 0;
  for
    (i=0; i< size; i++){
      if (temp_var < previous) goto overflow;
      previous = temp_var;
      temp_var+= (inputs[i]*inputs[i]);
    }
  temp_var = temp_var * size;
  if (temp_var < previous) goto overflow;
  temp_var =(temp_var - acc)/(((mp_limb_t)(size))*((mp_limb_t)(size)));
  return (temp_var);
overflow:
  printf("CRITICAL OVERFLOW ERROR IN var_calc!!!!!!\n\n");
  return 0;
}

int
main (int argc, char *argv[])
{
  int i = 0, j = 0, spurious = 0, k =0;
  mp_size_t limbs;
  mp_limb_t **times;
  mp_limb_t *variances;
  mp_limb_t *min_values;
  mp_limb_t max_dev = 0, min_time = 0, max_time = 0, prev_min =0, tot_var=0,
            max_dev_all=0, var_of_vars=0, var_of_mins=0, avg_mins=0;
  mp_ptr data1, data2, data3, data4,
         sdata1, sdata2, sdata3, sdata4;

  data1 = malloc(MAX_LIMBS*sizeof(mp_limb_t));
  data2 = malloc(MAX_LIMBS*sizeof(mp_limb_t));
  data3 = malloc(MAX_LIMBS*sizeof(mp_limb_t));
  data4 = malloc(MAX_LIMBS*sizeof(mp_limb_t));
  sdata1 = malloc(MAX_LIMBS*sizeof(mp_limb_t));
  sdata2 = malloc(MAX_LIMBS*sizeof(mp_limb_t));
  sdata3 = malloc(MAX_LIMBS*sizeof(mp_limb_t));
  sdata4 = malloc(MAX_LIMBS*sizeof(mp_limb_t));

  times = malloc(BOUND_OF_LOOP*sizeof(mp_limb_t*));
  if (!times) {
    printf( "unable to allocate memory for times\n");
    return 0;
  }
  for (j=0; j<BOUND_OF_LOOP; j++)
  {
    times[j] = malloc(SIZE_OF_STAT*sizeof(mp_limb_t));
    if (!times[j]) {
      printf( "unable to allocate memory for times[%d]\n", j);
      for (k=0; k<j; k++)
        free(times[k]);
      return 0;
    }
  }
  variances = malloc(BOUND_OF_LOOP*sizeof(mp_limb_t));
  if (!variances) {
    printf( "unable to allocate memory for variances\n");
    return 0;
  }
  min_values = malloc(BOUND_OF_LOOP*sizeof(mp_limb_t));
  if (!min_values) {
    printf( "unable to allocate memory for min_values\n");
    return 0;
  }

  printf("{");
  for (limbs = ((MAX_LIMBS - 1) % INCREMENT) + 1; limbs <= MAX_LIMBS; limbs = limbs + INCREMENT)
  {
    avg_mins = 0;

    // Time it!
    Filltimes(times, data1, data2, data3, data4, sdata1, sdata2, sdata3, sdata4, limbs);

    for (j=0; j<BOUND_OF_LOOP; j++)
    {
      max_dev = 0;
      min_time = 0;
      max_time = 0;
      for (i =0; i<SIZE_OF_STAT; i++)
      {
        if ((min_time == 0)||(min_time > times[j][i]))
          min_time = times[j][i];
        if (max_time < times[j][i])
          max_time = times[j][i];
      }
      max_dev = max_time - min_time;
      min_values[j] = min_time;
      if ((prev_min != 0) && (prev_min > min_time))
        spurious++;
      if (max_dev > max_dev_all)
        max_dev_all = max_dev;
      //variances[j] = var_calc(times[j], SIZE_OF_STAT);
      tot_var += variances[j];
      //printf( "loop_size:%d >>>> variance(cycles): %llu; max_deviation: %llu ;min time: %llu", j, variances[j], max_dev, min_time);
      prev_min = min_time;
      avg_mins += min_time;
    }
    //var_of_vars = var_calc(variances, BOUND_OF_LOOP);
    //var_of_mins = var_calc(min_values, BOUND_OF_LOOP);
    /*printf( "\n total number of spurious min values = %d", spurious);
    printf( "\n total variance = %llu", (tot_var/BOUND_OF_LOOP));
    printf( "\n absolute max deviation = %llu", max_dev_all);
    printf( "\n variance of variances = %llu", var_of_vars);
    printf( "\n variance of minimum values = %llu", var_of_mins);*/
    avg_mins = avg_mins / BOUND_OF_LOOP;
    printf("%ld: %ld", limbs, avg_mins);

    if (limbs < MAX_LIMBS)
      printf(", ");
  }
  printf("}");


  for (j=0; j<BOUND_OF_LOOP; j++)
  {
    free(times[j]);
  }
  free(times);
  free(variances);
  free(min_values);

  free(data1);
  free(data2);
  free(data3);
  free(data4);
  free(sdata1);
  free(sdata2);
  free(sdata3);
  free(sdata4);

  return 0;
}
