/*
 * 北京阿卡信息技术有限公司版权所有
 * 保留一切权力
 * 2004-05-21
 */
#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <time.h>

#include <string>

#include <socket++/sockinet.h>

#include <boost/filesystem/operations.hpp> // includes boost/filesystem/path.hpp
#include <boost/filesystem/fstream.hpp>    // ditto
#include <boost/lexical_cast.hpp>

//using namespace boost::lexical_cast;
using namespace boost::filesystem;


#define BUF_LEN 4096
#define EML_DIR "/home/NoSPAM/spool/working"
#define EML_PREFIX "emlfile.gw.nospam"

class qmail_hdrs
{
	public:
		char invalid_hdrs[6] ;
		size_t invalid_len ;

		char hdrs[2048];
		size_t len;

		qmail_hdrs( char *p, size_t n=0)
		{
			len = n;
			for ( size_t i=0; i<n; i++ ){
				hdrs[i] = p[n];
			}

			invalid_len = 5;
			memcpy ( invalid_hdrs, "F\0T\0\0", invalid_len ) ;
		}

		~qmail_hdrs(){;}

		bool valid()
		{
			if ( 0==len ) return false;

			for ( size_t i=0; i<invalid_len; i++ )
				if ( invalid_hdrs[i]!=hdrs[i] ) return true;

			return false;
		}

};

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
		string tcpremoteinfo, string emlfile, qmail_hdrs *hdrs )
{
	iosockinet io (sockbuf::sock_stream);

	try {
		io->connect ("127.0.0.1", "40307", "tcp");
	} catch ( ... ) {
		result = "443 connect to Engine failure.";
		return -1;
	}
	
cout << relayclient << "," << tcpremoteip << "," << tcpremoteinfo << "," << emlfile << "," << hdrs->len << endl;
	io << relayclient << endl;
	io << tcpremoteip << endl;
	io << tcpremoteinfo << endl;
	io << emlfile << endl;
	//io << hdrs << endl;
	io<<"ft"<<endl;

	char smtp_code[40+1], smtp_info[256+1], exit_code[4+1];
	io.getline( smtp_code, 40 );
	io.getline( smtp_info, 256 );
	io.getline( exit_code, 4 );

cout << "smtp_code: [" << smtp_code << "] smtp_info: [" << smtp_info << "] exit_code [" << exit_code << "]" << endl;
	result = smtp_code;
	result += " ";
        result += smtp_info;

	int ret;
	try {
		//ret = lexical_cast<int>exit_code;
		ret = atoi(exit_code);
	} catch (...) {
		ret = -1;
	}

	remove ( emlfile );
	return ret;
}

qmail_hdrs* grab_envelope_hdrs()
{
	char buf[2048];
	size_t n;

	n = read( 1, buf, sizeof(buf) );
	qmail_hdrs *hdrs = new qmail_hdrs ( buf, n );
	//if ( -1==n )

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

	string emlfile;
	qmail_hdrs *hdrs;

	int ret;
	string result;

	if ( RELAYCLIENT && strlen(RELAYCLIENT) )
		//relayclient = RELAYCLIENT;
		relayclient = "1";
	if ( TCPREMOTEINFO && strlen (TCPREMOTEINFO) )
		tcpremoteinfo = TCPREMOTEINFO;
	if ( TCPREMOTEIP && strlen (TCPREMOTEIP) )
		tcpremoteip = TCPREMOTEIP;

	//goto LABEL;
	cout << tcpremoteinfo << "," << relayclient << endl;

	emlfile = dump_stdin_to_file();
	//cout << "file_id: " << file_id << endl;
	
	if ( !exists( emlfile ) ){
		qns_err("443 ns can't get file.", 150);
	}

	hdrs = grab_envelope_hdrs();
	if ( !hdrs->valid() ) {
	  debug("g_e_h: no sender and no recips.");
	  //unlink(emlfile.c_str())
	  remove(emlfile);
	  qns_err("443 ns can't get hdr.", 150);
	}
for ( size_t i=0; i<hdrs->len; i++ ){
	if ( 0==hdrs->hdrs[i] ){
		cout << "\\0";
	}else{
		cout << hdrs->hdrs[i];
	}
}
cout << endl;
	qmail_parent_check();
LABEL:
	ret = net_process( result, relayclient, tcpremoteip, tcpremoteinfo, emlfile, hdrs );
	//ret = net_process( result, "127.0.0.2", "192.168.0.1", "", "/tmp/php.err", "Fzixia@zixia.net\0Tzixia@vmware.zixia.net\0\0");

	if ( -1==ret ){
		cerr << result << "\r\n";
		exit (111);
	}

	cerr << "[" << result << "]\r\n";
	exit ( ret );
}



