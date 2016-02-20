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

//#include <socket++/sockinet.h>
#include <socket++/sockunix.h>

#include <boost/filesystem/operations.hpp> // includes boost/filesystem/path.hpp
#include <boost/filesystem/fstream.hpp>    // ditto
#include "boost/date_time/posix_time/posix_time.hpp"
#include <boost/lexical_cast.hpp>


using namespace boost;
using namespace boost::posix_time;
using namespace std;


#define BUF_LEN 2048
#define EML_DIR "/home/NoSPAM/spool/working"
#define EML_PREFIX "emlfile.gw.nospam"
#define UNIXSOCKETFILE "/home/NoSPAM/.ns"

// Email磁盘文件
string emlfile;
ptime start_time(microsec_clock::local_time());
time_duration io_duration;
time_duration rpc_duration;

std::ofstream log_file("/home/NoSPAM/spool/ns-queue.debug", ios::out | ios::app );

void log( const string& what )
{

	//using namespace boost::posix_time;
	//using namespace boost::gregorian;

	ptime now = microsec_clock::local_time();
	//ptime now = posix_time::second_clock::universal_time();
	//time_t t;
	//posix_time::ptime now = posix_time::from_time_t( time(&t) );
	log_file << to_simple_string(now) << " " << getpid() << " " << what << "\n";
}


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
			string msg = "[" ;
			for ( size_t i=0; i<len; i++ ){
				if ( 0==hdrs[i] ){
					msg += "\\0";
				}else{
					msg +=  hdrs[i];
				}
			}
			log ( msg + "] size:" + boost::lexical_cast<string>(len) );
		}


};

void qns_err_n_exist( const char* smtp_msg, int exit_code )
{
	filesystem::remove(emlfile);
	if ( strlen(smtp_msg) ){
		cerr << smtp_msg << "\r\n";
	}

	filesystem::remove(emlfile);

	time_duration ms = microsec_clock::local_time() - start_time;
	
	log ( "Process time(ms): ns[" + lexical_cast<string>(rpc_duration.total_milliseconds())
			+ "] io[" + lexical_cast<string>(io_duration.total_milliseconds()) 
			+ "] total[" + lexical_cast<string>(ms.total_milliseconds()) 
			+ "]." 
	);

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
		qns_err_n_exist ( "443 qns_loader can't open file.", 150 );
		exit (150);
	}

	while( (len = (TEMP_FAILURE_RETRY( read(0,buffer,BUF_LEN))) ) ){
		if( len < 0 ){
			qns_err_n_exist ( "443 qns_loader can't read file.", 150 );
			exit (150);
		}
		len = TEMP_FAILURE_RETRY ( write ( fd, buffer, len) );
		if( len < 0 ){
			qns_err_n_exist ( "443 qns_loader can't write file.", 150 );
			exit (150);
		}
	}

	TEMP_FAILURE_RETRY( close ( fd ) );

	if ( -1==TEMP_FAILURE_RETRY ( rename ( tmp_emlfile, new_emlfile ) ) ){
		qns_err_n_exist ( "443 qns_loader can't rename file.", 150 );
	}

	return string(new_emlfile);
}


int net_process( string &result, 
		string relayclient, string tcpremoteip, 
		string tcpremoteinfo, string emlfile, qmail_hdrs *hdrs )
{
	//iosockinet io (sockbuf::sock_stream);
	iosockunix io (sockbuf::sock_stream);

	int retry=0;
	for(;;) {
		try {
			//io->connect ("127.0.0.1", "40307", "tcp");
			io->connect (UNIXSOCKETFILE);
			break;
		} catch ( ... ) {
			if (retry++<10){
				sleep(3);
				continue;
			}
			log ( "cant connect to engine" );
			qns_err_n_exist ( "443 noSPAM Engine temporarily unavailable.", 150 );
			return 150;
		}
	}

	log ( relayclient + "," + tcpremoteip + "," + tcpremoteinfo + "," + emlfile + "," );

	io << relayclient << endl;
	io << tcpremoteip << endl;
	io << tcpremoteinfo << endl;
	io << emlfile << endl;

	hdrs->dump();
	io.write ( hdrs->hdrs, hdrs->len );
	io << endl;

	io << flush;

	char smtp_code[4+1], smtp_info[256+1], exit_code[4+1];
	io.getline( smtp_code, 4 );
	smtp_code[4] = 0;
	io.getline( smtp_info, 256 );
	smtp_info[256] = 0;
	io.getline( exit_code, 4 );
	exit_code[4] = 0;

	if ( strlen(smtp_code) || strlen(smtp_info) ){
		result = smtp_code;
		result += " ";
		result += smtp_info;
	}else{
		result = "";
	}

	int ret;
	try {
		//ret = lexical_cast<int>exit_code;
		ret = atoi(exit_code);
	} catch (...) {
		result = "443 系统内部临时不可用";
		ret = 150;
	}

	filesystem::remove ( emlfile );
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
		log ( "Whoa! parent process is dead! Better die too..." );
		exit(111); 
	}
}



int main ()
{

	setuid ( 0 );
	setgid ( 0 );

	seteuid ( 0 );
	setegid ( 0 );

	log ( "============ New mail coming ==================" );

	string relayclient,tcpremoteinfo,tcpremoteip;

	char *RELAYCLIENT = getenv("RELAYCLIENT");
	char *TCPREMOTEINFO = getenv("TCPREMOTEINFO");
	char *TCPREMOTEIP = getenv("TCPREMOTEIP");

	qmail_hdrs *hdrs;

	int ret;
	string result;

	if ( RELAYCLIENT )
		//relayclient = RELAYCLIENT;
		relayclient = "1";
	if ( TCPREMOTEINFO && strlen (TCPREMOTEINFO) )
		tcpremoteinfo = TCPREMOTEINFO;
	if ( TCPREMOTEIP && strlen (TCPREMOTEIP) )
		tcpremoteip = TCPREMOTEIP;

	//	goto LABEL;

	ptime io_start_time(microsec_clock::local_time());
	emlfile = dump_stdin_to_file();
	io_duration = microsec_clock::local_time() - io_start_time;

	log ( "file_id: " + emlfile );

	if ( !filesystem::exists( emlfile ) ){
		qns_err_n_exist("443 ns can't get file.", 150);
	}

	hdrs = grab_envelope_hdrs();
	if ( !hdrs->valid() ) {
		log ( "g_e_h: no sender and no recips." );
		//unlink(emlfile.c_str())
		filesystem::remove(emlfile);
		qns_err_n_exist("443 ns can't get hdr.", 150);
	}

	qmail_parent_check();
	//LABEL:
	//hdrs->dump();
	ptime rpc_start_time(microsec_clock::local_time());
	ret = net_process( result, relayclient, tcpremoteip, tcpremoteinfo, emlfile, hdrs );
	rpc_duration = microsec_clock::local_time() - rpc_start_time;
	//hdrs = new qmail_hdrs ( "Fzixia@zixia.net\0Tzixia@vmware.zixia.net\0\0", 42);
	//ret = net_process( result, "127.0.0.2", "192.168.0.1", "", "/tmp/zixia.eml", hdrs );

	log ( string("net_process ret[") + lexical_cast<string>(ret) + "], result:[" + result + "]" );

	if ( -1==ret ){ // 出现错误
		qns_err_n_exist ( result.c_str(), 111 );
	}
	else if ( 0!=ret ){ // 需要有信息返回给smtpd
		qns_err_n_exist ( result.c_str(), ret );
	}

	//无需信息，投递正常
	qns_err_n_exist ( "", 0 );
}



