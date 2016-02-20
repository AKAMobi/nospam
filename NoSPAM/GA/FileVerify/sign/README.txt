1 加入声明
  
extern int DoSign (char *prikey_file, char *sign_file);

	参数prikey_file是密钥文件路径，如“home/pri”
	参数sign_file是要签名的文件路径

2 例子函数
void main()
{
  int ret_val;

  ret_val = DoSign("pri", "jj");

  if (ret_val == 0)
	printf("签名成功！");
}


3 其它返回值：
-1: 读取要签名的文件时出错
-2: 读取私钥文件时出错
-9: 其它错误

4 需要把sign.o和rsaref.a两个文件copy到编译目录下，参考Makefile编译

5 文件包括：
	私钥文件				如：pubkey
	要签名的文件				如：rule.xml

6 规则：
	签名文件是要校验的文件后加“.sig”后缀，签名成功后即生成