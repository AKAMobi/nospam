#include <stdio.h> 
#include <sys/param.h> 
#include <sys/ioctl.h> 
#include <sys/socket.h> 
#include <net/if.h> 
#include <netinet/in.h> 
#include <net/if_arp.h> 
#include <linux/hdreg.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>

/*
 * 底层接口，负责取回网卡的 MAC 数据
 */
unsigned char * get_mac_serial( char* result )
{
	register int fd, intrface;
	struct ifreq buf[16]; //MAXINTERFACES
	struct arpreq arp; 
	struct ifconf ifc; 
	int count = 0;
	char mac[12+1];

	result[0] = 0;

	if ((fd = socket (AF_INET, SOCK_DGRAM, 0)) >= 0) { 
		ifc.ifc_len = sizeof buf; 
		ifc.ifc_buf = (caddr_t) buf; 
		if (!ioctl (fd, SIOCGIFCONF, (char *) &ifc)) { 
			intrface = ifc.ifc_len / sizeof (struct ifreq); 
			count = 0;
			while (intrface-- > 0 && count++ < 2 ) 
			{ 
				if ( 0==strcmp("lo", buf[intrface].ifr_name) )
					continue;

				/*Get HW ADDRESS of the net card */ 
				if (!(ioctl (fd, SIOCGIFHWADDR, (char *) &buf[intrface]))) 
				{ 
					sprintf(mac,"%02x%02x%02x%02x%02x%02x", 
							(unsigned char)buf[intrface].ifr_hwaddr.sa_data[0], 
							(unsigned char)buf[intrface].ifr_hwaddr.sa_data[1], 
							(unsigned char)buf[intrface].ifr_hwaddr.sa_data[2], 
							(unsigned char)buf[intrface].ifr_hwaddr.sa_data[3], 
							(unsigned char)buf[intrface].ifr_hwaddr.sa_data[4], 
							(unsigned char)buf[intrface].ifr_hwaddr.sa_data[5]); 
					strncat( result, mac, 12 );
				} 
			} 
		} else 
			perror ("cpm: ioctl"); 

	} else 
		perror ("cpm: socket"); 

	close (fd); 

	return 0;
}

/*
 * 底层接口，负责取回硬盘序列号
 */
unsigned char* get_hd_serial(unsigned char* result) {
	static char *sealcode = "IENCOASI2304KJASDIWE234984ALSKDWMZXOIUDWD";
	struct hd_driveid id;
	int fd;

	int i;

	fd=open("/dev/hda",O_RDONLY);
	if (fd<0) {
		return "open_hd_serial_err";
	}
	if (ioctl(fd,HDIO_GET_IDENTITY,&id)){
		return "ioctl_hd_error";
	}

	for (i=0;i<20 ;i++ )
	{
		if (id.serial_no[i]){
			sprintf( result+i*2, "%02x", (unsigned char)id.serial_no[i] );
		} else {
			sprintf( result+i*2, "%02x", (unsigned char)sealcode[i] );
		}
	}
	result[40]=0;
	return result;
}

/*
 * 上层接口，这个函数返回硬件识别号
 */
unsigned char * get_prodno ( unsigned char* prodno )
{
	unsigned char serial_orig[1024] = "";
	unsigned char result[128] = "";


	get_mac_serial( result );
	strncat( serial_orig, result, 24 );

	get_hd_serial ( result );
	strncat ( serial_orig, result, 40 );

	md5_hex( serial_orig, prodno );

	return prodno;
}

/*
 * 传入 License 文件数据，返回文件数据的校验值
 */
unsigned char * get_license_ex ( unsigned char* license_dat, unsigned char* license_ex )
{
	unsigned char license_ex_orig[40960] = "";
	//unsigned char result[128] = "";


	strcat ( license_ex_orig, "zixia" );
	strcat ( license_ex_orig, license_dat );
	strcat ( license_ex_orig, "K12" );
	strcat ( license_ex_orig, license_dat );
	strcat ( license_ex_orig, "wMail" );

	md5_base64( license_ex_orig, license_ex );

	return license_ex;
}



/*
 * 传入硬件识别号，生成 License 号
 */
unsigned char * get_license ( unsigned char* prodno, unsigned char* license )
{
	unsigned char license_orig[1024] = "";
	//unsigned char result[128] = "";


	strcat ( license_orig, "zixia" );
	strcat ( license_orig, prodno );
	strcat ( license_orig, "K12" );
	strcat ( license_orig, prodno );
	strcat ( license_orig, "wMail" );

	md5_hex( license_orig, license );

	return license;
}

/*
 * 检查 license 是否为 本地prodno 的license
 */
int check_license_match ( unsigned char* license )
{
	unsigned char right_license[1024+1], prodno[1024+1];

	get_prodno( prodno );
	get_license( prodno, right_license );

	if ( 0==strcmp(right_license,license) ) // match
		return 0;

	// not match
	return -1;

}


/*
 * 检查 license_ex 校验和是否成功
 */
int check_license_ex_match ( unsigned char* license_file, unsigned char* license_ex )
{
	unsigned char right_license_ex[1024+1];

	get_license_ex( license_file, right_license_ex );

	if ( 0==strcmp(right_license_ex,license_ex) ) // match
		return 0;

	// not match
	return -1;

}

/*
 * 传入 License 文件，检查文件是否合法；
 */
int check_license_file ( const char* filepath )
{
	char license_file[32768];
	char buf[32768];
	char bufbak[32768];
	FILE *fp;

	char ProductLicense[128];
	char ProductLicenseExt[128];

	char *key, *val;

	fp = fopen ( filepath, "r" );
	if ( NULL==fp ){
		printf ( "Can't open license file: %s\n", filepath );
		return -1;
	}

	while ( NULL!=fgets( buf, 4096, fp ) ){
		strcpy( bufbak, buf );

		key = strtok ( buf, "=" );
		val = strtok ( NULL, "=" );

		//printf ( "key: [%s], val: [%s]\n", key, val );
		if ( NULL!=key && !strcmp( "ProductLicenseExt", key ) ){
			strcpy ( ProductLicenseExt, val );
			break;
		}

		strcat( license_file, bufbak );

		if ( NULL==key || NULL==val ){
			continue;
		}

		if ( !strcmp( "ProductLicense", key ) ){
			strcpy ( ProductLicense, val );
		}

	}
	fclose ( fp );

	ProductLicense[strlen(ProductLicense)-1] = 0;
	ProductLicenseExt[strlen(ProductLicenseExt)-1] = 0;
	license_file[strlen(license_file)-1] = 0;

	//printf ( "LicenseDat: [%s]\n\n", license_file );
	//printf ( "ProductLicense: [%s]\n", ProductLicense );
	//printf ( "ProductLicenseExt: [%s]\n", ProductLicenseExt );

	if ( -1==check_license_match(ProductLicense) )
		return -1;


	if ( -1==check_license_ex_match(license_file,ProductLicenseExt) )
		return -1;

	return 0;
}

/*
 main (argc, argv) 
	register int argc; 
	register char *argv[]; 
{ 
	unsigned char prodno[1024];
	unsigned char license[1024];

	get_prodno ( prodno );
	printf ( "prodno: %s\n", prodno );

	get_license ( prodno, license );
	printf ( "license: %s\n", license );

	get_license_ex ( prodno, license );
	printf ( "license_ex: %s\n", license );

	check_license_file ( "/home/NoSPAM/etc/License.dat" );
}


*/
