#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <time.h>

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
	int fd;

	char tmp_emlfile[128];
	char new_emlfile[128];
	char file_id[128];
	snprintf ( file_id, 128, "%s.%d.%d", EML_PREFIX, (int)time(0), getpid() );
	snprintf ( tmp_emlfile, 128, "%s/tmp/%s", EML_DIR, file_id );
	snprintf ( new_emlfile, 128, "%s/new/%s", EML_DIR, file_id );

	//printf ( "%s\n", emlfile );

  /*
   * XXX we should do it
   * if (-f "$scandir/$wmaildir/tmp/$file_id" || -f "$scandir/$wmaildir/new/$file_id") {
    &error_condition("$file_id exists, try again later");
  }
  */
	fd = TEMP_FAILURE_RETRY( open(tmp_emlfile,O_WRONLY|O_CREAT) );

	if ( fd<0 ){
		fprintf ( stderr, "443 qns_loader can't open file\r\n" );
		exit (150);
	}

	while( (len = (TEMP_FAILURE_RETRY( read(0,buffer,BUF_LEN))) ) ){
		if( len < 0 ){
			fprintf ( stderr, "443 qns_loader can't read file\r\n" );
			exit (150);
		}
		len = TEMP_FAILURE_RETRY ( write ( fd, buffer, len) );
		if( len < 0 ){
			fprintf ( stderr, "443 qns_loader can't write file\r\n" );
			exit (150);
		}
	}

	TEMP_FAILURE_RETRY( close ( fd ) );

	TEMP_FAILURE_RETRY ( rename ( tmp_emlfile, new_emlfile ) );

	TEMP_FAILURE_RETRY ( setenv ( "AKA_FILE_ID", file_id, 1 ) );
}


int main( int argc, char* argv[] )
{

	dump_stdin_to_file();

	setuid ( 0 );
	setgid ( 0 );

	seteuid ( 0 );
	setegid ( 0 );

	execvp( QNS_BINARY, argv );

	fprintf ( stderr, "443 qns_loader error\n" );
	return 150;
}


