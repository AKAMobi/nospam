/* MDDRIVER.C - test driver for MD2, MD4 and MD5
 */

/* Copyright (C) 1990-2, RSA Data Security, Inc. Created 1990. All
   rights reserved.

   RSA Data Security, Inc. makes no representations concerning either
   the merchantability of this software or the suitability of this
   software for any particular purpose. It is provided "as is"
   without express or implied warranty of any kind.

   These notices must be retained in any copies of any part of this
   documentation and/or software.
 */

/* The following makes MD default to MD5 if it has not already been
   defined with C compiler flags.
 */
#ifndef MD
//#define MD MD5
#define MD 5
#endif

#include <stdio.h>
#include <time.h>
#include <string.h>
#include "global.h"
#if MD == 2
#include "md2.h"
#endif
#if MD == 4
#include "md4.h"
#endif
#if MD == 5
#include "md5.h"
#endif

/* Length of test block, number of test blocks.
 */
#define TEST_BLOCK_LEN 1000
#define TEST_BLOCK_COUNT 1000

static void MDString PROTO_LIST ((char *));
static void MDTimeTrial PROTO_LIST ((void));
static void MDTestSuite PROTO_LIST ((void));
static void MDFile PROTO_LIST ((char *));
static void MDFilter PROTO_LIST ((void));
static void MDPrint PROTO_LIST ((unsigned char [16]));

#if MD == 2
#define MD_CTX MD2_CTX
#define MDInit MD2Init
#define MDUpdate MD2Update
#define MDFinal MD2Final
#endif
#if MD == 4
#define MD_CTX MD4_CTX
#define MDInit MD4Init
#define MDUpdate MD4Update
#define MDFinal MD4Final
#endif
#if MD == 5
#define MD_CTX MD5_CTX
#define MDInit MD5Init
#define MDUpdate MD5Update
#define MDFinal MD5Final
#endif

static char* hex_16(const unsigned char* from, char* to)
{
    static char *hexdigits = "0123456789abcdef";
    const unsigned char *end = from + 16;
    char *d = to;

    while (from < end) {
	*d++ = hexdigits[(*from >> 4)];
	*d++ = hexdigits[(*from & 0x0F)];
	from++;
    }
    *d = '\0';
    return to;
}

static char* base64_16(const unsigned char* from, char* to)
{
    static char* base64 =
	"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    const unsigned char *end = from + 16;
    unsigned char c1, c2, c3;
    char *d = to;

    while (1) {
	c1 = *from++;
	*d++ = base64[c1>>2];
	if (from == end) {
	    *d++ = base64[(c1 & 0x3) << 4];
	    break;
	}
	c2 = *from++;
	c3 = *from++;
	*d++ = base64[((c1 & 0x3) << 4) | ((c2 & 0xF0) >> 4)];
	*d++ = base64[((c2 & 0xF) << 2) | ((c3 & 0xC0) >>6)];
	*d++ = base64[c3 & 0x3F];
    }
    *d = '\0';
    return to;
}

static char* md5_digest(const unsigned char* string, char* digest)
{
	MD_CTX context;
	unsigned int len = strlen (string);

	MDInit (&context);
	MDUpdate (&context, string, len);
	MDFinal (digest, &context);
	return digest;
}


char* md5_hex(const unsigned char* string, char* result)
{
	unsigned char digest[16];
	md5_digest( string, digest );
	hex_16( digest, result );
	return result;
}

char* md5_base64(const unsigned char* string, char* result)
{
	unsigned char digest[16];
	md5_digest( string, digest );
	base64_16( digest, result );
	return result;
}

/* Digests a string and prints the result.
 */
static void MDString (string)
	char *string;
{
	MD_CTX context;
	unsigned char digest[16];
	unsigned int len = strlen (string);

	MDInit (&context);
	MDUpdate (&context, string, len);
	MDFinal (digest, &context);

	printf ("MD%d (\"%s\") = ", MD, string);
	MDPrint (digest);
	printf ("\n");
}

/* Measures the time to digest TEST_BLOCK_COUNT TEST_BLOCK_LEN-byte
   blocks.
 */
static void MDTimeTrial ()
{
	MD_CTX context;
	time_t endTime, startTime;
	unsigned char block[TEST_BLOCK_LEN], digest[16];
	unsigned int i;

	printf
		("MD%d time trial. Digesting %d %d-byte blocks ...", MD,
		 TEST_BLOCK_LEN, TEST_BLOCK_COUNT);

	/* Initialize block */
	for (i = 0; i < TEST_BLOCK_LEN; i++)
		block[i] = (unsigned char)(i & 0xff);

	/* Start timer */
	time (&startTime);

	/* Digest blocks */
	MDInit (&context);
	for (i = 0; i < TEST_BLOCK_COUNT; i++)
		MDUpdate (&context, block, TEST_BLOCK_LEN);
	MDFinal (digest, &context);

	/* Stop timer */
	time (&endTime);

	printf (" done\n");
	printf ("Digest = ");
	MDPrint (digest);
	printf ("\nTime = %ld seconds\n", (long)(endTime-startTime));
	printf
		("Speed = %ld bytes/second\n",
		 (long)TEST_BLOCK_LEN * (long)TEST_BLOCK_COUNT/(endTime-startTime));
}

/* Digests a reference suite of strings and prints the results.
 */
static void MDTestSuite ()
{
	printf ("MD%d test suite:\n", MD);

	MDString ("");
	MDString ("a");
	MDString ("abc");
	MDString ("message digest");
	MDString ("abcdefghijklmnopqrstuvwxyz");
	MDString
		("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789");
	MDString
		("1234567890123456789012345678901234567890\
		 1234567890123456789012345678901234567890");
}

/* Digests a file and prints the result.
 */
static void MDFile (filename)
	char *filename;
{
	FILE *file;
	MD_CTX context;
	int len;
	unsigned char buffer[1024], digest[16];

	if ((file = fopen (filename, "rb")) == NULL)
		printf ("%s can't be opened\n", filename);

	else {
		MDInit (&context);
		while (len = fread (buffer, 1, 1024, file))
			MDUpdate (&context, buffer, len);
		MDFinal (digest, &context);

		fclose (file);

		printf ("MD%d (%s) = ", MD, filename);
		MDPrint (digest);
		printf ("\n");
	}
}

/* Digests the standard input and prints the result.
 */
static void MDFilter ()
{
	MD_CTX context;
	int len;
	unsigned char buffer[16], digest[16];

	MDInit (&context);
	while (len = fread (buffer, 1, 16, stdin))
		MDUpdate (&context, buffer, len);
	MDFinal (digest, &context);

	MDPrint (digest);
	printf ("\n");
}

/* Prints a message digest in hexadecimal.
 */
static void MDPrint (digest)
	unsigned char digest[16];
{
	unsigned int i;
	char result[33];

	printf ( "MDPrint:\n" );
	for (i = 0; i < 16; i++)
		printf ("%02x", digest[i]);

	printf ( "\nhex_16:\n" );
	hex_16( digest, result );
	printf ( "\t%s\n", result );

	printf ( "base64_16:\n" );
	base64_16( digest, result );
	printf ( "\t%s\n", result );
}

/* Main driver.

   Arguments (may be any combination):
   -sstring - digests string
   -t       - runs time trial
   -x       - runs test script
   filename - digests file
   (none)   - digests standard input
int main (argc, argv)
	int argc;
	char *argv[];
{
	int i;
	char result[33];

	if (argc > 1){
		//printf ( "md5_digest: 	[%s] => [%s]\n", argv[1], md5_digest(argv[1],result) );
		printf ( "md5_hex: 	[%s] => [%s]\n", argv[1], md5_hex(argv[1],result) );
		printf ( "md5_base64: 	[%s] => [%s]\n", argv[1], md5_base64(argv[1],result) );
	} else
		MDFilter ();

	return (0);
}


 */
char * zixia(const unsigned char* s)
{
	return "hehe";
}
