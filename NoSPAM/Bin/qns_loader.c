#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#define QNS_BINARY "/var/qmail/bin/ns-queue"
//#define QINS_BINARY "/var/qmail/bin/ins-queue"

#define BUF_LEN 32768
/*
 * ns-queue dump eml to here, so we write eml here too.
 */
#define EML_DIR "/home/NoSPAM/spool/working/"
#define EML_PREFIX "emlfile.gw.nospam.aka.cn"

void dump_stdin_to_file()
{
	int len;
	unsigned char buffer[BUF_LEN];
	FILE *fp;

	char tmp_emlfile[128];
	char new_emlfile[128];
	char file_id[128];
	snprintf ( file_id, 128, "%s.%d.%d", EML_PREFIX, time(0), getpid() );
	snprintf ( tmp_emlfile, 128, "%s/tmp/%s", EML_DIR, file_id );
	snprintf ( new_emlfile, 128, "%s/new/%s", EML_DIR, file_id );

	//printf ( "%s\n", emlfile );

  /*
   * XXX we should do it
   * if (-f "$scandir/$wmaildir/tmp/$file_id" || -f "$scandir/$wmaildir/new/$file_id") {
    &error_condition("$file_id exists, try again later");
  }
  */
	fp = fopen ( tmp_emlfile, "w" );
	if ( NULL==fp ){
		fprintf ( stderr, "443 qns_loader can't open file\r\n" );
		exit (150);
	}

	while (len = fread (buffer, 1, BUF_LEN, stdin))
		fwrite (buffer, 1, len, fp);

	fclose ( fp );

	rename ( tmp_emlfile, new_emlfile );

	setenv ( "AKA_FILE_ID", file_id, 1 );
}


/*
 * if ( RELAYCLIENT || TCPREMOTEINFO )
 * 	ins = 1;
 */
int main( int argc, char* argv[] )
{

	//execvp(argv[1], argv+1);
	//strcpy ( argv[0], QNS_BINARY );

	dump_stdin_to_file();

	setuid ( 0 );
	setgid ( 0 );

	seteuid ( 0 );
	setegid ( 0 );

	//if ( strstr(argv[0],"qins_loader") ){
	//	execvp( QINS_BINARY, argv );
	//}else{
		execvp( QNS_BINARY, argv );
	//}

	fprintf ( stderr, "443 qns_loader error\n" );
	return 150;
}


