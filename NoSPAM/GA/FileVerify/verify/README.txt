1 ��������
  
extern int DoVerify (char *pubkey_file, char *verify_file);

	����pubkey_file�ǹ�Կ�ļ�·�����硰home/pub��
	����verify_file��Ҫǩ�����ļ�·��

2 ���Ӻ���
void main()
{
  int ret_val;

  ret_val = DoVerify("pub", "jj");

  if (ret_val == 0)
	printf("У��ϸ�");
}


3 ��������ֵ��
-1: ��ȡҪУ����ļ�ʱ����
-2: ��ȡ��Կ�ļ�ʱ����
-3: ��ȡǩ���ļ�ʱ����
-9: ��������

4 ��Ҫ��verify.o��rsaref.a�����ļ�copy������Ŀ¼�£��ο�Makefile����

5 �ļ�������
	��Կ�ļ�				�磺pubkey
	ҪУ����ļ�				�磺rule.xml
	ҪУ����ļ���ǩ���ļ�			�磺rule.xml.sig

6 ����
	ǩ���ļ���ҪУ����ļ���ӡ�.sig����׺