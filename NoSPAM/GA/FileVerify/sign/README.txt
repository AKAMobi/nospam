1 ��������
  
extern int DoSign (char *prikey_file, char *sign_file);

	����prikey_file����Կ�ļ�·�����硰home/pri��
	����sign_file��Ҫǩ�����ļ�·��

2 ���Ӻ���
void main()
{
  int ret_val;

  ret_val = DoSign("pri", "jj");

  if (ret_val == 0)
	printf("ǩ���ɹ���");
}


3 ��������ֵ��
-1: ��ȡҪǩ�����ļ�ʱ����
-2: ��ȡ˽Կ�ļ�ʱ����
-9: ��������

4 ��Ҫ��sign.o��rsaref.a�����ļ�copy������Ŀ¼�£��ο�Makefile����

5 �ļ�������
	˽Կ�ļ�				�磺pubkey
	Ҫǩ�����ļ�				�磺rule.xml

6 ����
	ǩ���ļ���ҪУ����ļ���ӡ�.sig����׺��ǩ���ɹ�������