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
#include <fstream>

#include <socket++/sockinet.h>

#include <boost/filesystem/operations.hpp> // includes boost/filesystem/path.hpp
#include <boost/filesystem/fstream.hpp>    // ditto
#include <boost/lexical_cast.hpp>

//using namespace boost::lexical_cast;
using namespace boost::filesystem;


#define BUF_LEN 2048
#define EML_DIR "/home/NoSPAM/spool/working"
#define EML_PREFIX "emlfile.gw.nospam"

std::ofstream zlog("/var/log/cpp.debug", ios::out | ios::app );

class qmail_hdrs
{
	public:
		char invalid_hdrs[6] ;
		size_t invalid_len ;

		char hdrs[2048];
		size_t len;

		qmail_hdrs( char *p, size_t n=0)
		{
			//printf ( "p=%s\n", p );
			len = n;
			for ( size_t i=0; i<n; i++ ){
				hdrs[i] = p[i];
				//printf ( "i:%d, hdrs[i]:%d\n", i, hdrs[i] );
			}

			//dump();
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

		void dump()
		{
			zlog << "qmail_hdrs: p=" << hdrs << ", len=" <<  len << endl;
			zlog << "[" ;
			for ( size_t i=0; i<len; i++ ){
				if ( 0==hdrs[i] ){
					zlog << "\\0";
				}else{
					zlog << hdrs[i];
				}
			}
			zlog << "]" << endl;
		}


};

void qns_err( const char* smtp_msg, int exit_code )
{
	cerr << smtp_msg << "\r\n";
	exit(exit_code);
}


string dump_stdin_to_file()
{
	int len;
	unsigned char buffer[BUF_LEN];
	int fd;

	char tmp_emlfile[128+1];
	char new_emlfile[128+1];
	char file_id[128+1];

	snprintf ( file_id, 128, "%s.%d.%d", EML_PREFIX, (int)time(0), getpid() );
	file_id[128]=0;
	snprintf ( tmp_emlfile, 128, "%s/tmp/%s", EML_DIR, file_id );
	tmp_emlfile[128]=0;
	snprintf ( new_emlfile, 128, "%s/new/%s", EML_DIR, file_id );
	new_emlfile[128]=0;

	//printf ( "%s\n", emlfile );

	/*
	 * XXX we should do it
	 * if (-f "$scandir/$wmaildir/tmp/$file_id" || -f "$scandir/$wmaildir/new/$file_id") {
	 &error_condition("$file_id exists, try again later");
	 }
	 */
	fd = TEMP_FAILURE_RETRY( open(tmp_emlfile,O_WRONLY|O_CREAT, S_IRWXU|S_IROTH ) );

	if ( fd<0 ){
		qns_err ( "443 qns_loader can't open file.", 150 );
		exit (150);
	}

	while( (len = (TEMP_FAILURE_RETRY( read(0,buffer,BUF_LEN))) ) ){
		if( len < 0 ){
			qns_err ( "443 qns_loader can't read file.", 150 );
			exit (150);
		}
		len = TEMP_FAILURE_RETRY ( write ( fd, buffer, len) );
		if( len < 0 ){
			qns_err ( "443 qns_loader can't write file.", 150 );
			exit (150);
		}
	}

	TEMP_FAILURE_RETRY( close ( fd ) );

	zlog << "rename " << tmp_emlfile << " to " << new_emlfile << endl;
	if ( -1==TEMP_FAILURE_RETRY ( link ( tmp_emlfile, new_emlfile ) ) ){
		qns_err ( "443 qns_loader can't link file.", 150 );
	}
	if ( -1==TEMP_FAILURE_RETRY ( unlink ( tmp_emlfile ) ) ){
		zlog << "qns_loader can't unlink file." << endl;
	}

	return string(new_emlfile);
}


int net_process( string &result, 
		string relayclient, string tcpremoteip, 
		string tcpremoteinfo, string emlfile, qmail_hdrs *hdrs )
{
	iosockinet io (sockbuf::sock_stream);

	zlog << "try connect..." << endl;
	try {
		io->connect ("127.0.0.1", "40307", "tcp");
	} catch ( ... ) {
		qns_err ( "443 Engine temporarily unavailable.", 150 );
		return 150;
	}

	zlog << relayclient << "," << tcpremoteip << "," << tcpremoteinfo << "," << emlfile << "," << endl;

	io << relayclient << endl;
	io << tcpremoteip << endl;
	io << tcpremoteinfo << endl;
	io << emlfile << endl;

	hdrs->dump();
	io.write ( hdrs->hdrs, hdrs->len );
	io << endl;

	char smtp_code[4+1], smtp_info[256+1], exit_code[4+1];
	io.getline( smtp_code, 4 );
	smtp_code[4] = 0;
	io.getline( smtp_info, 256 );
	smtp_info[256] = 0;
	io.getline( exit_code, 4 );
	exit_code[4] = 0;

	zlog << "smtp_code: [" << smtp_code << "] smtp_info: [" << smtp_info << "] exit_code [" << exit_code << "]" << endl;
	result = smtp_code;
	result += " ";
	result += smtp_info;

	int ret;
	try {
		//ret = lexical_cast<int>exit_code;
		ret = atoi(exit_code);
	} catch (...) {
		result = "443 系统内部临时不可用";
		ret = 150;
	}

	remove ( emlfile );
	return ret;
}

qmail_hdrs* grab_envelope_hdrs()
{
	char buf[2048];
	size_t n;

	n = read( 1, buf, sizeof(buf) );
	return new qmail_hdrs ( buf, n );
}


void qmail_parent_check ()
{
	pid_t ppid = getppid();

	if ( 1==ppid )  {
		zlog << "\n!!!!!!!!!!!!!!!!!!!!!!!!!q_s_c: Whoa! parent process is dead! (ppid=$ppid) Better die too..." << endl ;
		exit(111); 
	}
}


int main ()
{
	setuid ( 0 );
	setgid ( 0 );

	seteuid ( 0 );
	setegid ( 0 );


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

	//	goto LABEL;
	zlog << tcpremoteinfo << "," << relayclient << endl;

	emlfile = dump_stdin_to_file();
	zlog << "file_id: " << emlfile << endl;

	if ( !exists( emlfile ) ){
		qns_err("443 ns can't get file.", 150);
	}

	hdrs = grab_envelope_hdrs();
	if ( !hdrs->valid() ) {
		zlog << "g_e_h: no sender and no recips." << endl;
		//unlink(emlfile.c_str())
		remove(emlfile);
		qns_err("443 ns can't get hdr.", 150);
	}

	qmail_parent_check();
	//LABEL:
	//hdrs->dump();
	ret = net_process( result, relayclient, tcpremoteip, tcpremoteinfo, emlfile, hdrs );
	//hdrs = new qmail_hdrs ( "Fzixia@zixia.net\0Tzixia@vmware.zixia.net\0\0", 42);
	//ret = net_process( result, "127.0.0.2", "192.168.0.1", "", "/tmp/zixia.eml", hdrs );

	zlog << "net_process ret " << ret << ", result: " << result << endl;

	if ( -1==ret ){
		cerr << result << "\r\n";
		exit (111);
	}
	else if ( 0!=ret ){
		qns_err ( result.c_str(), ret );
		exit ( ret );
	}
	exit (0);
}



