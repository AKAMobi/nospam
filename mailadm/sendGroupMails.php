<?php
require_once("vpopadm.inc.php");
?>
<HTML>
<HEAD>
<meta http-equiv="content-type" content="text/html; charset=gb2312">
<TITLE>群发信件</TITLE>
</HEAD>
<BODY>
<DIV align="center">
<h2>群发信件</h2>
<?php

if (!adminPerm(PERM_ADMIN_USERCONTROL) ){
?>
<br>
您没有访问该网页的权限。<br>
<?php
} else {
if ($_POST['action']=='send') {
	sendGroup($_POST['groups'],$_POST['sendAll']=='true', $_POST['mailbox'], $_POST['title'],$_POST['content']);
} else {
	showMenu();
}
}



?>
</div>
</BODY>
</HTML>
<?php

function sendGroup($sendGroups, $isSendAll, $mailbox,$title, $content) {
	$passwd_file = VPOPMAILHOME . 'domains/' . DOMAIN . '/vpasswd';

	$user_profile = VPOPMAILHOME . 'domains/' . DOMAIN . '/' . USERPROFILE;

    $h_user_profile = fopen ($user_profile,"a+");
   
    if ($h_user_profile == NULL ){
        echo "错误：用户数据文件无法打开。<br>";
		exit(-1);
    }

	if (!$isSendAll){
   
		flock($h_user_profile, LOCK_SH);
		fseek($h_user_profile,0, SEEK_SET);
		$userinfo_list=array();
		while (!feof($h_user_profile)){
			$userinfo = fgets($h_user_profile,1024); 
			list ($id, $unit, $department, $station, $id_code, $create_time, $is_public, $note, $group) = explode( ':', $userinfo);
			$isPublic=$is_public?'Y':'N';

			array_push($userinfo_list,array("id" => $id,
											"unit" => $unit,
											"department" => $department,
											"station" => $station,
											"id_code" => $id_code,
											"create_time" => $create_time,
											"is_public" => $isPublic,
											"note" => $note,
											"group"=> trim($group))
			);
		}
		flock($h_user_profile, LOCK_UN);
		fclose($h_user_profile);
		$sendgrouplist=explode(',', $sendGroups);
	}
    

	$user_list = file( $passwd_file );
    $mail_count=count($user_list);



	for( $i = 0 ; $i < $mail_count ; $i++)	{
			list( $user_account, $xxx, $xxx, $xxx, $user_name, $xxx, $user_quota )  = explode( ':', $user_list[$i] );
			if ($isSendAll) {
				mail($user_account.'@'.DOMAIN,$title,$content,$mailbox);
				continue;
			}
			for ($t=0; $t<count($userinfo_list); $t++){
				if (!strcmp($user_account, $userinfo_list[$t]['id'])) {
					break;
				} 
			}
			if ($t<count($userinfo_list)){
				$groups=explode(',',trim($userinfo_list[$t]['group']));
				foreach ($sendgrouplist as $sendgroup) {
					if (in_array($sendgroup,$groups)) {
						
						mail($user_account.'@'.DOMAIN,$title,$content,$mailbox);
						break;
					}
				}
			}
 
	}
	echo "发送成功！";
	return false;
}

function showMenu(){
	$groupdefine_profile = VPOPMAILHOME . 'domains/' . DOMAIN . '/' . GROUPFILE;
   
    $h_groupdefine_profile = fopen ($groupdefine_profile,"r");
   
    if ($h_groupdefine_profile == NULL ){
        echo "错误：用户组数据文件无法打开。<br>";
		exit(-1);
    }
   
    flock($h_groupdefine_profile, LOCK_SH);
    

	$group_list=array();
	$group_count=0;

   	while (!feof($h_groupdefine_profile)){
	    $tmp = fgets($h_groupdefine_profile,1024); 
	    $groupinfo= explode( ',', $tmp);
		if (trim($groupinfo[1])!=''){
			$group_list[]=$groupinfo[1];
			$group_count++;
		}
	}

   	flock($h_groupdefine_profile, LOCK_UN);
   	
   	fclose($h_groupdefine_profile);
    
	if ($group_count<=0) {
?>
	目前尚无用户组定义！
<?php
	} else {
?>
请指定待发送的用户组,若不选择则信件将发给全部用户：
<select id="oGroupList" size=10 multiple>
<?php
	for ($i=0;$i<$group_count;$i++){
?>
	<option ><?php echo $group_list[$i] ?></option>
<?php
	}
?>
</select>
<?php
	}
?>
<hr width="97%">
<script language="JavaScript">
	function doSend(){
        var dot=false;
		if (oForm.oContent.value=='') {
			alert('群发信件内容为空!');
			return false;
		}
		if (oForm.oTitle.value=='') {
			alert('群发信件标题为空!');
			return false;
		}
		if (oForm.oMailbox.value=='') {
			alert('管理员地址为空!');
			return false;
		}
		if (typeof(oGroupList) != "undefined") {
			for (i=0;i<oGroupList.length;i++){
			if (oGroupList.options(i).selected) {
				if (dot) {
					oForm.oGroups.value+=',';
				} else {
					oForm.oSendAll.value="false";
					dot=true;
				}
				oForm.oGroups.value+=oGroupList.options(i).text;
			}
			}
		}
		return oForm.submit();
	}
		
</script>
<form action="<?php echo $_SERVER['PHP_SELF'] ; ?>" method="POST" id="oForm">
<input type="hidden" name="groups" id="oGroups" >
<input type="hidden" name="action" value="send">
<input type="hidden" name="sendAll" id="oSendAll" value="true">
<table>
<tr>
<td>管理员邮箱</td><td><input type="text" name="mailbox" id="oMailbox"></td>
</tr>
<tr>
<td>群发邮件标题</td><td><input type="text" name="title" id="oTitle"></td>
</tr>
<tr>
<td>群发信件内容</td><td><textarea name="content" id="oContent" style="width:250; height:400"></textarea></td>
</tr>
</table>
<input type="button" value="发送群体信件" onclick="doSend();">
</form>
<?php
}
?>
