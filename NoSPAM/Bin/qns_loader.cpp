/*
 * 北京阿卡信息技术有限公司版权所有
 * 保留一切权力
 * 2004-05-21
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <time.h>


#include <socket++/sockinet.h>

#include <boost/filesystem/operations.hpp> // includes boost/filesystem/path.hpp
#include <boost/filesystem/fstream.hpp>    // ditto
#include <boost/lexical_cast.hpp>

using namespace boost::filesystem;
//using namespace boost::lexical_cast;


#define BUF_LEN 32768
#define EML_DIR "/home/NoSPAM/spool/working/"
#define EML_PREFIX "emlfile.gw.nospam.aka.cn"

string dump_stdin_to_file()
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
	fd = TEMP_FAILURE_RETRY( open(tmp_emlfile,O_WRONLY|O_CREAT, S_IRWXU|S_IROTH ) );

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

	return string(new_emlfile);
}


int net_process( string &result, 
		string relayclient, string tcpremoteip, 
		string tcpremoteinfo, string emlfile, string hdrs )
{
	iosockinet io (sockbuf::sock_stream);

	try {
		io->connect ("127.0.0.1", "40307", "tcp");
	} catch ( ... ) {
		result = "443 connect to Engine failure.";
		return -1;
	}
	
	io << relayclient << endl;
	io << tcpremoteip << endl;
	io << tcpremoteinfo << endl;
	io << emlfile << endl;
	io << hdrs << endl;

	string smtp_code, smtp_info, exit_code;
	io >> smtp_code;
	io >> smtp_info;
	io >> exit_code;

	result = smtp_code + " " + smtp_info;

	int ret;
	try {
		//ret = lexical_cast<int>exit_code;
		ret = atoi(exit_code.c_str());
	} catch (...) {
		ret = -1;
	}

	remove ( emlfile );
	return ret;
}

string grab_envelope_hdrs()
{
	string hdrs;
	char buf[80+1];
	ssize_t n;
	while ( 0<(n=read(1, buf, 80 )) )
	{
		buf[n] = 0;
		hdrs += buf;
	}
	return hdrs;
}


void debug ( char* msg )
{
	;
}

void qmail_parent_check ()
{
  pid_t ppid = getppid();

  if ( 1==ppid )  {
    debug("\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!q_s_c: Whoa! parent process is dead! (ppid=$ppid) Better die too...");
    exit(111); 
  }
}


void qns_err( char* const smtp_msg, int exit_code )
{
	cerr << smtp_msg << "\r\n";
	exit(exit_code);
}

int old_main( int argc, char* argv[] )
{

	dump_stdin_to_file();

	setuid ( 0 );
	setgid ( 0 );

	seteuid ( 0 );
	setegid ( 0 );

	//execvp( QNS_BINARY, argv );

	fprintf ( stderr, "443 qns_loader error\n" );
	return 150;
}

int main ()
{
	string relayclient,tcpremoteinfo,tcpremoteip;

	char *RELAYCLIENT = getenv("RELAYCLIENT");
	char *TCPREMOTEINFO = getenv("TCPREMOTEINFO");
	char *TCPREMOTEIP = getenv("TCPREMOTEIP");

	if ( RELAYCLIENT && strlen(RELAYCLIENT) )
		//relayclient = RELAYCLIENT;
		relayclient = "1";
	if ( TCPREMOTEINFO && strlen (TCPREMOTEINFO) )
		tcpremoteinfo = TCPREMOTEINFO;
	if ( TCPREMOTEIP && strlen (TCPREMOTEIP) )
		tcpremoteip = TCPREMOTEIP;

	//cout << tcpremoteinfo << "," << relayclient << endl;

	string emlfile = dump_stdin_to_file();
	//cout << "file_id: " << file_id << endl;
	
	if ( !exists( emlfile ) ){
		qns_err("443 ns can't get file.", 150);
	}

	string hdrs = grab_envelope_hdrs();
	if ( !hdrs.length() || "F\0T\0\0"==hdrs )
	{
	  debug("g_e_h: no sender and no recips.");
	  //unlink(emlfile.c_str())
	  remove(emlfile);
	  qns_err("443 ns can't get hdr.", 150);
	}

	qmail_parent_check();
	int ret;
	string result;
	ret = net_process( result, relayclient, tcpremoteip, tcpremoteinfo, emlfile, hdrs );

	if ( -1==ret ){
		exit (111);
	}

	cerr << result << "\r\n";
	exit ( ret );
}



