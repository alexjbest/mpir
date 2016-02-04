#include <stdio.h>
#include <stdlib.h>

int
main (int argc, char *argv[])
{
  int i;
  long limbs = 2;long *data1 = (long *)malloc(limbs * sizeof(long));
  ifdef(`PPs',`  long *data2 = (long *)malloc(limbs * sizeof(long)); ')
  ifdef(`PPPs',` long *data2 = (long *)malloc(limbs * sizeof(long));
                 long *data3 = (long *)malloc(limbs * sizeof(long)); ')

  printf("{");
  for (i = 1; i <= 100; i++)
  {
    printf("%d: ", i);
    //TIME THIS:
    ifdef(`PPs',`
    funcname (data1, data2, limbs); ') //TODO could maybe use ifelse based switch here which might look nicer
    ifdef(`PPPs',`
    funcname (data1, data2, data3, limbs); ')
    printf("%d", 0);
    if (i < 100)
      printf(", ");
  }
  printf("}");


                free(data1);
  ifdef(`PPs', `free(data2);')
  ifdef(`PPPs',`free(data2);
                free(data3);')

  return 0;
}
