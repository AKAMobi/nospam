<?
require_once("vpopadm.inc.php");
?>
<HTML>
<HEAD>
<meta http-equiv="content-type" content="text/html; charset=gb2312">
<TITLE>Anti-Spam SMTP����</TITLE>
<style>

table { font-size:x-small;}

.title {font-size:medium;color:#ffffff;background-color:#6fa6e6;}
</style>
</HEAD>
<BODY>

<!-- Insert HTML here -->

<?

function doConfig(){
		if (!adminPerm(PERM_ADMIN_ADMINCONTROL) ){
?>
		<br>
		��û�з��ʸ���ҳ��Ȩ�ޡ�<br>
<?php
		return false;
	}
	if (!isset($_POST['type'])){ 
		return false;
	}
	$handle=fopen("/var/qmail/control/mfcheck","w");	
	if (!$handle) {
		echo "�����޷��������ã�<br>";
		return false;
	}
	fputs($handle,$_POST['type']);
	fclose($handle);
	return true;
}

if ( (isset($_REQUEST['doConfig']) && doConfig()) ){
	echo "�����޸ĳɹ���<br>";
} else {

	$handle=fopen("/var/qmail/control/mfcheck","r");
	if ($handle) {
		$info=fscanf($handle,"%d");
		list($config)=$info;
		$config=intval($config);
		if ( ($config<0) || ($config>4) ) {
			$config=0;
		}
		fclose($handle);
	} else {
		$config=0;
	}
?>
<center>
<form action="<? echo $_SERVER['PHP_SELF']; ?>" method=post>
<INPUT type="hidden" name="doConfig">
<table border=0>
<tr align="center" bgcolor=#6fa6e6>
<td colspan="2" class=title><b>����Anti-Spam SMTP����</b></td>
</tr>
<tr>
	<td colspan="2">Anti-Spam�����趨��<?php 
	$note=array("��","��","��(�Ƽ�)","�ܸ�","���");
	for ($i=0;$i<5;$i++) {
?>
<input type=radio name="type" value="<?php echo $i ;?>" <?php if ($config==$i) echo "checked"?>><?php echo $note[$i]; ?>
<?php
	}
	?>
	</td>
</tr>
<tr align="center" >
	<td colspan=2><input type=submit name="adduser" value="  ��  ��  ">
	</td>
</tr>
</table>

</form>
</br>
<?
}
?>
</BODY>
</HTML>
