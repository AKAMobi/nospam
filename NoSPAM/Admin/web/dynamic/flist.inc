<?
function DrawListTable($sList, $sSection, $sTitle, $sColumn, $bAccess)
{
	global $spamconf;
	
	$rList = $spamconf->getList($sList,$sSection);

	$pagenum = $_GET["pagenum"];
	if(!$pagenum || $pagenum < 1)
		$pagenum = PAGENUM;

	$iSize = count($rList);
	
	if($iSize == 0)
		$pages = 1;
	else
		$pages = $iSize%$pagenum? intval(($iSize/$pagenum)+1):intval(($iSize/$pagenum));
	
	$page = $_GET['page'];
	if(!$page || $page < 1)
		$page = 1;
	if($page > $pages)
		$page = $pages;
?>
<form action="<?=$_SERVER['PHP_SELF']."?action=del"?>" method="post">
<table class="RuleTB" width="100%">
<caption><?=$sTitle?></caption>
<tr class="TableTitle2">
<?if($bAccess){?>
	<th><?=_("Select")?></th>
<?}?>
	<th><?=_("No.")?></th>
	<th><?=$sColumn?></th>
	<th><?=_("Note")?></th>
<?if($bAccess){?>
	<th><?=_("Edit")?></th>
<?}?>
</tr>
<?
	if($iSize > 0){
		$i = 1;$j=1;
		foreach($rList as $key=>$note){
			if($i>($page-1)*$pagenum && $i<=$page*$pagenum){
				$className = $j%2? "TableBody1":"TableBody2";
?>
<tr class="<?=$className?>">
<?if($bAccess){?>
	<td align="center"><input type="checkbox" name="key[]" value="<?=$key?>"></td>
<?}?>
	<td><?=$i?></td>
	<td><?=$key?></td>
	<td><?=$note?></td>
<?if($bAccess){?>
	<td align="center">
		<input type="button" value="<?=_("Modify")?>" onclick="location.href='<?=$_SERVER['PHP_SELF']."?key=$key&action=modify"?>'">
		<input type="button" value="<?=_("Delete")?>" onclick="location.href='<?=$_SERVER['PHP_SELF']."?key=$key&action=del"?>'">
	</td>
<?}?>
</tr>
<?
				$j++;
			}
			$i++;
		}
	}
?>
</table>
<script>
function jump()
{
	page = document.all.oPage.value;
	pagenum = document.all.oPagenum.value;
	location.href="<?=$_SERVER['PHP_SELF']?>?page="+page+"&pagenum="+pagenum;
}
</script>
<table border="0" width="100%"> 
<tr>
<td align="center">
<?if($bAccess){?>
<input type="button" value="<?=_("Add")?>" onclick="location.href='<?=$_SERVER['PHP_SELF']."?action=add"?>'">
<input type="submit" name="submit" value="<?=_("Delete")?>">
<?}?>
</td>
<td align="right">
<?
echo "<a href='".$_SERVER['PHP_SELF']."?page=1&pagenum=$pagenum'>&lt;&lt;</a>&nbsp;";
if($page == 1)
	echo "&lt;&nbsp;";
else
	echo "<a href='".$_SERVER['PHP_SELF']."?page=".($page-1)."&pagenum=$pagenum'>&lt;</a>&nbsp;";

for($i = 1; $i <= $pages; $i++){
	if($i == $page)
		echo $i."&nbsp;";
	else
		echo "<a href='".$_SERVER['PHP_SELF']."?page=$i&pagenum=$pagenum'>$i</a>&nbsp;";
}

if($page == $pages)
	echo "&gt;&nbsp;";
else
	echo "<a href='".$_SERVER['PHP_SELF']."?page=".($page+1)."&pagenum=$pagenum'>&gt;</a>&nbsp;";
echo "<a href='".$_SERVER['PHP_SELF']."?page=$pages&pagenum=$pagenum'>&gt;&gt;</a>&nbsp;";
?>
<?=_("Jump to Page ")?><select name="oPage" id="oPage" onchange="jump()">
<?
for($i = 1; $i <= $pages; $i++){
	if($i == $page)
		echo "<option value='$i' selected>$i";
	else
		echo "<option value='$i'>$i";
}
?>
</select> <?=_(", ")?> <select name="oPagenum" id="oPagenum" onchange="jump()">
<?
for($i = 5; $i <= 30; $i+=5){
	if($i == $pagenum)
		echo "<option value='$i' selected>$i";
	else
		echo "<option value='$i'>$i";
}
?>
</select><?=_(" records/page")?>
</td>
</tr>
</table>
</form>
<?
}

function DrawModifyTable($sList, $sSection, $sTitle, $sColumn, $bAccess)
{
	global $spamconf;

	if(!$bAccess){
		print _("You have not permission to modify system config");
		exit(-1);
	}
	
	$rList = $spamconf->getList($sList,$sSection);
?>
<html>
<body>
<form method="POST" action="<?=$_SERVER['PHP_SELF']."?action=save"?>">
<input type="hidden" name="type" value="modify">
<input type="hidden" name="oKey" value="<?=$_GET["key"]?>">
<table width="50%" border="1" align="center">
<caption><?=_("Add").$sTitle?></caption>
<tr>
	<th scope="row"><?=$sColumn?>:</th>
	<td align="left"><input type="text" name="key" value="<?=$_GET["key"]?>"></td>
</tr>
<tr>
	<th scope="row"><?=_("Note")?>:</th>
	<td align="left"><input type="text" name="note" value="<?=$rList[$_GET["key"]]?>"></td>
</tr>
<tr>
	<th colspan="2"><input type="submit" value="<?=_("Save")?>" /><input type="reset" value="<?=_("Reset")?>" /></th>
</tr>
<table>
</form>
<?
}

function DrawAddTable($sList, $sSection, $sTitle, $sColumn, $bAccess)
{
	global $spamconf;

	if(!$bAccess){
		print _("You have not permission to modify system config");
		exit(-1);
	}
	
	$rList = $spamconf->getList($sList,$sSection);
?>
<html>
<body>
<form method="POST" action="<?=$_SERVER['PHP_SELF']."?action=save"?>">
<table width="50%" border="1" align="center">
<caption>Ìí¼Ó<?=$sTitle?></caption>
<tr>
	<th scope="row"><?=$sColumn?>£º</th>
	<td align="left"><input type="text" name="key"></td>
</tr>
<tr>
	<th scope="row"><?=_("Note")?>:</th>
	<td align="left"><input type="text" name="note"></td>
</tr>
<tr>
	<th colspan="2"><input type="submit" value="<?=_("Save")?>" /><input type="reset" value="<?=_("Reset")?>" /></th>
</tr>
<table>
</form>
<?
}

function SaveData($sList, $sSection, $sColumn, $bAccess)
{
	global $spamconf;

	if(!$bAccess){
		print _("You have not permission to modify system config");
		exit(-1);
	}
	$rList = $spamconf->getList($sList,$sSection);
	
	if(isset($_POST['type']) && $_POST['type']=="modify")
		unset($rList[$_POST['oKey']]);
	elseif (array_key_exists($_POST['key'],$rList)){
		echo _("Same ").$sColumn._(" has existed");
		exit(-1);
	}

	$rList[$_POST['key']] = $_POST['note'];
	$spamconf->setList($sList,$rList,$sSection);
	$spamconf->save();
}

function DeleteData($sList, $sSection, $bAccess)
{
	global $spamconf;

	if(!$bAccess){
		print _("You have not permission to modify system config");
		exit(-1);
	}

	$rList = $spamconf->getList($sList,$sSection);
	
	$key = $_REQUEST["key"];

	if(is_array($key)){
		if(count($key) > 0){
			foreach($key as $tmp)
				unset($rList[$tmp]);
		}
	}else{
		unset($rList[$key]);
	}
	$spamconf->setList($sList,$rList,$sSection);
	$spamconf->save();
}
?>
