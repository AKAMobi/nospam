
/*
** Copyright 2000-2002 Double Precision, Inc.
** See COPYING for distribution information.
**
** $Id$
*/

#include "unicode.h"
static const unicode_char ibm864_unicode [256]={
0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,
16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,
32,33,34,35,36,1642,38,39,40,41,42,43,44,45,46,47,
48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,
64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,
80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,
96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,
112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,
176,183,8729,8730,9618,9472,9474,9532,9508,9516,9500,9524,9488,9484,9492,9496,
946,8734,966,177,189,188,8776,171,187,65271,65272,0,0,65275,65276,0,
160,173,65154,163,164,65156,0,0,65166,65167,65173,65177,1548,65181,65185,65189,
1632,1633,1634,1635,1636,1637,1638,1639,1640,1641,65233,1563,65201,65205,65209,1567,
162,65152,65153,65155,65157,65226,65163,65165,65169,65171,65175,65179,65183,65187,65191,65193,
65195,65197,65199,65203,65207,65211,65215,65217,65221,65227,65231,166,172,247,215,65225,
1600,65235,65239,65243,65247,65251,65255,65259,65261,65263,65267,65213,65228,65230,65229,65249,
65149,1617,65253,65257,65260,65264,65266,65232,65237,65269,65270,65245,65241,65265,9632,0
};
static const char ibm864_uc [256]={
(char)0x00,(char)0x01,(char)0x02,(char)0x03,(char)0x04,(char)0x05,(char)0x06,(char)0x07,
(char)0x08,(char)0x09,(char)0x0a,(char)0x0b,(char)0x0c,(char)0x0d,(char)0x0e,(char)0x0f,
(char)0x10,(char)0x11,(char)0x12,(char)0x13,(char)0x14,(char)0x15,(char)0x16,(char)0x17,
(char)0x18,(char)0x19,(char)0x1a,(char)0x1b,(char)0x1c,(char)0x1d,(char)0x1e,(char)0x1f,
(char)0x20,(char)0x21,(char)0x22,(char)0x23,(char)0x24,(char)0x25,(char)0x26,(char)0x27,
(char)0x28,(char)0x29,(char)0x2a,(char)0x2b,(char)0x2c,(char)0x2d,(char)0x2e,(char)0x2f,
(char)0x30,(char)0x31,(char)0x32,(char)0x33,(char)0x34,(char)0x35,(char)0x36,(char)0x37,
(char)0x38,(char)0x39,(char)0x3a,(char)0x3b,(char)0x3c,(char)0x3d,(char)0x3e,(char)0x3f,
(char)0x40,(char)0x41,(char)0x42,(char)0x43,(char)0x44,(char)0x45,(char)0x46,(char)0x47,
(char)0x48,(char)0x49,(char)0x4a,(char)0x4b,(char)0x4c,(char)0x4d,(char)0x4e,(char)0x4f,
(char)0x50,(char)0x51,(char)0x52,(char)0x53,(char)0x54,(char)0x55,(char)0x56,(char)0x57,
(char)0x58,(char)0x59,(char)0x5a,(char)0x5b,(char)0x5c,(char)0x5d,(char)0x5e,(char)0x5f,
(char)0x60,(char)0x41,(char)0x42,(char)0x43,(char)0x44,(char)0x45,(char)0x46,(char)0x47,
(char)0x48,(char)0x49,(char)0x4a,(char)0x4b,(char)0x4c,(char)0x4d,(char)0x4e,(char)0x4f,
(char)0x50,(char)0x51,(char)0x52,(char)0x53,(char)0x54,(char)0x55,(char)0x56,(char)0x57,
(char)0x58,(char)0x59,(char)0x5a,(char)0x7b,(char)0x7c,(char)0x7d,(char)0x7e,(char)0x7f,
(char)0x80,(char)0x81,(char)0x82,(char)0x83,(char)0x84,(char)0x85,(char)0x86,(char)0x87,
(char)0x88,(char)0x89,(char)0x8a,(char)0x8b,(char)0x8c,(char)0x8d,(char)0x8e,(char)0x8f,
(char)0x90,(char)0x91,(char)0x92,(char)0x93,(char)0x94,(char)0x95,(char)0x96,(char)0x97,
(char)0x98,(char)0x99,(char)0x9a,(char)0x9b,(char)0x9c,(char)0x9d,(char)0x9e,(char)0x9f,
(char)0xa0,(char)0xa1,(char)0xa2,(char)0xa3,(char)0xa4,(char)0xa5,(char)0xa6,(char)0xa7,
(char)0xa8,(char)0xa9,(char)0xaa,(char)0xab,(char)0xac,(char)0xad,(char)0xae,(char)0xaf,
(char)0xb0,(char)0xb1,(char)0xb2,(char)0xb3,(char)0xb4,(char)0xb5,(char)0xb6,(char)0xb7,
(char)0xb8,(char)0xb9,(char)0xba,(char)0xbb,(char)0xbc,(char)0xbd,(char)0xbe,(char)0xbf,
(char)0xc0,(char)0xc1,(char)0xc2,(char)0xc3,(char)0xc4,(char)0xc5,(char)0xc6,(char)0xc7,
(char)0xc8,(char)0xc9,(char)0xca,(char)0xcb,(char)0xcc,(char)0xcd,(char)0xce,(char)0xcf,
(char)0xd0,(char)0xd1,(char)0xd2,(char)0xd3,(char)0xd4,(char)0xd5,(char)0xd6,(char)0xd7,
(char)0xd8,(char)0xd9,(char)0xda,(char)0xdb,(char)0xdc,(char)0xdd,(char)0xde,(char)0xdf,
(char)0xe0,(char)0xe1,(char)0xe2,(char)0xe3,(char)0xe4,(char)0xe5,(char)0xe6,(char)0xe7,
(char)0xe8,(char)0xe9,(char)0xea,(char)0xeb,(char)0xec,(char)0xed,(char)0xee,(char)0xef,
(char)0xf0,(char)0xf1,(char)0xf2,(char)0xf3,(char)0xf4,(char)0xf5,(char)0xf6,(char)0xf7,
(char)0xf8,(char)0xf9,(char)0xfa,(char)0xfb,(char)0xfc,(char)0xfd,(char)0xfe,(char)0xff
};
static const char ibm864_lc [256]={
(char)0x00,(char)0x01,(char)0x02,(char)0x03,(char)0x04,(char)0x05,(char)0x06,(char)0x07,
(char)0x08,(char)0x09,(char)0x0a,(char)0x0b,(char)0x0c,(char)0x0d,(char)0x0e,(char)0x0f,
(char)0x10,(char)0x11,(char)0x12,(char)0x13,(char)0x14,(char)0x15,(char)0x16,(char)0x17,
(char)0x18,(char)0x19,(char)0x1a,(char)0x1b,(char)0x1c,(char)0x1d,(char)0x1e,(char)0x1f,
(char)0x20,(char)0x21,(char)0x22,(char)0x23,(char)0x24,(char)0x25,(char)0x26,(char)0x27,
(char)0x28,(char)0x29,(char)0x2a,(char)0x2b,(char)0x2c,(char)0x2d,(char)0x2e,(char)0x2f,
(char)0x30,(char)0x31,(char)0x32,(char)0x33,(char)0x34,(char)0x35,(char)0x36,(char)0x37,
(char)0x38,(char)0x39,(char)0x3a,(char)0x3b,(char)0x3c,(char)0x3d,(char)0x3e,(char)0x3f,
(char)0x40,(char)0x61,(char)0x62,(char)0x63,(char)0x64,(char)0x65,(char)0x66,(char)0x67,
(char)0x68,(char)0x69,(char)0x6a,(char)0x6b,(char)0x6c,(char)0x6d,(char)0x6e,(char)0x6f,
(char)0x70,(char)0x71,(char)0x72,(char)0x73,(char)0x74,(char)0x75,(char)0x76,(char)0x77,
(char)0x78,(char)0x79,(char)0x7a,(char)0x5b,(char)0x5c,(char)0x5d,(char)0x5e,(char)0x5f,
(char)0x60,(char)0x61,(char)0x62,(char)0x63,(char)0x64,(char)0x65,(char)0x66,(char)0x67,
(char)0x68,(char)0x69,(char)0x6a,(char)0x6b,(char)0x6c,(char)0x6d,(char)0x6e,(char)0x6f,
(char)0x70,(char)0x71,(char)0x72,(char)0x73,(char)0x74,(char)0x75,(char)0x76,(char)0x77,
(char)0x78,(char)0x79,(char)0x7a,(char)0x7b,(char)0x7c,(char)0x7d,(char)0x7e,(char)0x7f,
(char)0x80,(char)0x81,(char)0x82,(char)0x83,(char)0x84,(char)0x85,(char)0x86,(char)0x87,
(char)0x88,(char)0x89,(char)0x8a,(char)0x8b,(char)0x8c,(char)0x8d,(char)0x8e,(char)0x8f,
(char)0x90,(char)0x91,(char)0x92,(char)0x93,(char)0x94,(char)0x95,(char)0x96,(char)0x97,
(char)0x98,(char)0x99,(char)0x9a,(char)0x9b,(char)0x9c,(char)0x9d,(char)0x9e,(char)0x9f,
(char)0xa0,(char)0xa1,(char)0xa2,(char)0xa3,(char)0xa4,(char)0xa5,(char)0xa6,(char)0xa7,
(char)0xa8,(char)0xa9,(char)0xaa,(char)0xab,(char)0xac,(char)0xad,(char)0xae,(char)0xaf,
(char)0xb0,(char)0xb1,(char)0xb2,(char)0xb3,(char)0xb4,(char)0xb5,(char)0xb6,(char)0xb7,
(char)0xb8,(char)0xb9,(char)0xba,(char)0xbb,(char)0xbc,(char)0xbd,(char)0xbe,(char)0xbf,
(char)0xc0,(char)0xc1,(char)0xc2,(char)0xc3,(char)0xc4,(char)0xc5,(char)0xc6,(char)0xc7,
(char)0xc8,(char)0xc9,(char)0xca,(char)0xcb,(char)0xcc,(char)0xcd,(char)0xce,(char)0xcf,
(char)0xd0,(char)0xd1,(char)0xd2,(char)0xd3,(char)0xd4,(char)0xd5,(char)0xd6,(char)0xd7,
(char)0xd8,(char)0xd9,(char)0xda,(char)0xdb,(char)0xdc,(char)0xdd,(char)0xde,(char)0xdf,
(char)0xe0,(char)0xe1,(char)0xe2,(char)0xe3,(char)0xe4,(char)0xe5,(char)0xe6,(char)0xe7,
(char)0xe8,(char)0xe9,(char)0xea,(char)0xeb,(char)0xec,(char)0xed,(char)0xee,(char)0xef,
(char)0xf0,(char)0xf1,(char)0xf2,(char)0xf3,(char)0xf4,(char)0xf5,(char)0xf6,(char)0xf7,
(char)0xf8,(char)0xf9,(char)0xfa,(char)0xfb,(char)0xfc,(char)0xfd,(char)0xfe,(char)0xff
};
static const char ibm864_tc [256]={
(char)0x00,(char)0x01,(char)0x02,(char)0x03,(char)0x04,(char)0x05,(char)0x06,(char)0x07,
(char)0x08,(char)0x09,(char)0x0a,(char)0x0b,(char)0x0c,(char)0x0d,(char)0x0e,(char)0x0f,
(char)0x10,(char)0x11,(char)0x12,(char)0x13,(char)0x14,(char)0x15,(char)0x16,(char)0x17,
(char)0x18,(char)0x19,(char)0x1a,(char)0x1b,(char)0x1c,(char)0x1d,(char)0x1e,(char)0x1f,
(char)0x20,(char)0x21,(char)0x22,(char)0x23,(char)0x24,(char)0x25,(char)0x26,(char)0x27,
(char)0x28,(char)0x29,(char)0x2a,(char)0x2b,(char)0x2c,(char)0x2d,(char)0x2e,(char)0x2f,
(char)0x30,(char)0x31,(char)0x32,(char)0x33,(char)0x34,(char)0x35,(char)0x36,(char)0x37,
(char)0x38,(char)0x39,(char)0x3a,(char)0x3b,(char)0x3c,(char)0x3d,(char)0x3e,(char)0x3f,
(char)0x40,(char)0x41,(char)0x42,(char)0x43,(char)0x44,(char)0x45,(char)0x46,(char)0x47,
(char)0x48,(char)0x49,(char)0x4a,(char)0x4b,(char)0x4c,(char)0x4d,(char)0x4e,(char)0x4f,
(char)0x50,(char)0x51,(char)0x52,(char)0x53,(char)0x54,(char)0x55,(char)0x56,(char)0x57,
(char)0x58,(char)0x59,(char)0x5a,(char)0x5b,(char)0x5c,(char)0x5d,(char)0x5e,(char)0x5f,
(char)0x60,(char)0x41,(char)0x42,(char)0x43,(char)0x44,(char)0x45,(char)0x46,(char)0x47,
(char)0x48,(char)0x49,(char)0x4a,(char)0x4b,(char)0x4c,(char)0x4d,(char)0x4e,(char)0x4f,
(char)0x50,(char)0x51,(char)0x52,(char)0x53,(char)0x54,(char)0x55,(char)0x56,(char)0x57,
(char)0x58,(char)0x59,(char)0x5a,(char)0x7b,(char)0x7c,(char)0x7d,(char)0x7e,(char)0x7f,
(char)0x80,(char)0x81,(char)0x82,(char)0x83,(char)0x84,(char)0x85,(char)0x86,(char)0x87,
(char)0x88,(char)0x89,(char)0x8a,(char)0x8b,(char)0x8c,(char)0x8d,(char)0x8e,(char)0x8f,
(char)0x90,(char)0x91,(char)0x92,(char)0x93,(char)0x94,(char)0x95,(char)0x96,(char)0x97,
(char)0x98,(char)0x99,(char)0x9a,(char)0x9b,(char)0x9c,(char)0x9d,(char)0x9e,(char)0x9f,
(char)0xa0,(char)0xa1,(char)0xa2,(char)0xa3,(char)0xa4,(char)0xa5,(char)0xa6,(char)0xa7,
(char)0xa8,(char)0xa9,(char)0xaa,(char)0xab,(char)0xac,(char)0xad,(char)0xae,(char)0xaf,
(char)0xb0,(char)0xb1,(char)0xb2,(char)0xb3,(char)0xb4,(char)0xb5,(char)0xb6,(char)0xb7,
(char)0xb8,(char)0xb9,(char)0xba,(char)0xbb,(char)0xbc,(char)0xbd,(char)0xbe,(char)0xbf,
(char)0xc0,(char)0xc1,(char)0xc2,(char)0xc3,(char)0xc4,(char)0xc5,(char)0xc6,(char)0xc7,
(char)0xc8,(char)0xc9,(char)0xca,(char)0xcb,(char)0xcc,(char)0xcd,(char)0xce,(char)0xcf,
(char)0xd0,(char)0xd1,(char)0xd2,(char)0xd3,(char)0xd4,(char)0xd5,(char)0xd6,(char)0xd7,
(char)0xd8,(char)0xd9,(char)0xda,(char)0xdb,(char)0xdc,(char)0xdd,(char)0xde,(char)0xdf,
(char)0xe0,(char)0xe1,(char)0xe2,(char)0xe3,(char)0xe4,(char)0xe5,(char)0xe6,(char)0xe7,
(char)0xe8,(char)0xe9,(char)0xea,(char)0xeb,(char)0xec,(char)0xed,(char)0xee,(char)0xef,
(char)0xf0,(char)0xf1,(char)0xf2,(char)0xf3,(char)0xf4,(char)0xf5,(char)0xf6,(char)0xf7,
(char)0xf8,(char)0xf9,(char)0xfa,(char)0xfb,(char)0xfc,(char)0xfd,(char)0xfe,(char)0xff
};


static unicode_char *c2u(const struct unicode_info *u, const char *cp, int *ip)
{
	return (unicode_ibm864_c2u(cp, ip, ibm864_unicode));
}

static char *u2c(const struct unicode_info *u, const unicode_char *cp, int *ip)
{
	return (unicode_ibm864_u2c(cp, ip, ibm864_unicode));
}

static char *toupper_func(const struct unicode_info *u, const char *cp, int *ip)
{
	return (unicode_iso8859_convert(cp, ip, ibm864_uc));
}

static char *tolower_func(const struct unicode_info *u, const char *cp, int *ip)
{
	return (unicode_iso8859_convert(cp, ip, ibm864_lc));
}

static char *totitle_func(const struct unicode_info *u, const char *cp, int *ip)
{
	return (unicode_iso8859_convert(cp, ip, ibm864_tc));
}

const struct unicode_info unicode_IBM_864 = {
	"IBM864",
	0,
	c2u,
	u2c,
	toupper_func,
	tolower_func,
	totitle_func};
