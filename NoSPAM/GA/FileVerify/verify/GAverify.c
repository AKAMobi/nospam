#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int DoVerify (char *, char *);

static void usage( char* prog_name )
{
	printf ( "Usage:\n\t%s PublicKey File\n\n", prog_name );
}

int main(int argc,char* argv[])
{
  int ret_val;
  
  if ( 3!=argc ){
	  usage( argv[0] );
	  return -1;
  }

  ret_val = DoVerify( argv[1], argv[2] );
  
  if (ret_val == 0){
  	printf("0: Verify OK!\n");
  }else{
  	printf("%d: Verify ERR!\n", ret_val);
  }
  return ret_val ;
}
