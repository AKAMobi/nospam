1 加入声明
  
extern int DoVerify (char *pubkey_file, char *verify_file);

	参数pubkey_file是公钥文件路径，如“home/pub”
	参数verify_file是要签名的文件路径

2 例子函数
void main()
{
  int ret_val;

  ret_val = DoVerify("pub", "jj");

  if (ret_val == 0)
	printf("校验合格！");
}


3 其它返回值：
-1: 读取要校验的文件时出错
-2: 读取公钥文件时出错
-3: 读取签名文件时出错
-9: 其它错误

4 需要把verify.o和rsaref.a两个文件copy到编译目录下，参考Makefile编译

5 文件包括：
	公钥文件				如：pubkey
	要校验的文件				如：rule.xml
	要校验的文件的签名文件			如：rule.xml.sig

6 规则：
	签名文件是要校验的文件后加“.sig”后缀