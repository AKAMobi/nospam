<HTML>
<HEAD>
<meta http-equiv="content-type" content="text/html; charset=gb2312">
<TITLE>��ʾ�û��б�</TITLE>
<style>
.userAccount {color: #0000FF;text-decoration: underline; font-size: x-small;}
.userAccount_on {color: #0000FF;text-decoration: none; font-size: x-small;}
TD {font-size: x-small;}
BODY {font-size: x-small;}
span {font-size: x-small;}
</style>
</HEAD>
<BODY onclick="hideFilterMenu();">
<OBJECT id="userlist" CLASSID="clsid:333C7BC4-460F-11D0-BC04-0080C7055A83" VIEWASTEXT>
	<PARAM NAME="DataURL" VALUE="userlist.php">
	<PARAM NAME="UseHeader" VALUE="True">
	<PARAM NAME="CHARSET" VALUE="GB2312">
</OBJECT>
<SCRIPT language="JScript">
var filterCol="";


function sortOrder(cols) {  
	var s=new String(userlist.sort);
	var a=s.split(";");
	var i;
	for (i=0;i<a.length;i++){
		if (a[i]==("+"+cols)){
			return 1;
		}
		if (a[i]==("-"+cols)){
			return -1;
		}
	}
	return 0;
}


function clearSortOrder(){
	oSortOn_account.innerHTML="";
	oSortOn_name.innerHTML="";
	oSortOn_unit.innerHTML="";
	oSortOn_department.innerHTML="";
}


function showSortOrder(cols){
	var s=sortOrder(cols);
	if (s==1) {
		document.all.item("oSortOn_"+cols).innerHTML="��";
		return ;
	}
	if (s==-1) {
		document.all.item("oSortOn_"+cols).innerHTML="��";
		return ;
	}
	document.all.item("oSortOn_"+cols).innerHTML="";
}

function sort(cols){
	var s=sortOrder(cols); 
	var temp=new String(userlist.sort);
	var re;
	if ((window.event!=null) && (window.event.ctrlKey) ){  //������ctrl��
		if (s==0) { //ԭ��sortlist��û�и��ֶ�
			userlist.sort+="+"+cols+";";
		} else { //ԭ��sortlist���и��ֶ�
			if (s==-1) { 
				re=new RegExp("[-]"+cols+";","i");
				userlist.Sort=temp.replace(re,"");
			} else {
				re=new RegExp("[+]"+cols+";","i");
				userlist.Sort=temp.replace(re,"");
			}
		}

	} else { //δ����ctrl��
		if (s==0) { //ԭ��sortlist��û�и��ֶ�
			clearSortOrder();
			userlist.sort="+"+cols+";";
		} else { //ԭ��sortlist���и��ֶ�
			if (s==-1) { 
				re=new RegExp("[-]"+cols,"i");
				userlist.Sort=temp.replace(re,"+"+cols);
			} else {
				re=new RegExp("[+]"+cols,"i");
				userlist.Sort=temp.replace(re,"-"+cols);
			}
		}
	}
	showSortOrder(cols);
	userlist.reset();
}

function filter(cols){
	filterCol=cols;
	
    oFilterMenu.style.display="block";
	oFilterMenu.style.top=window.event.y;
	oFilterMenu.style.left=window.event.x;
	
	window.event.returnValue=false;
}

function hideFilterMenu(){
    oFilterMenu.style.display="none";
}

function chooseUser(){
	document.location.href = "userInfo.php?id=" + event.srcElement.innerText;
}

function doFilter(value){
	if (value=="") {
		userlist.filter=filterCol+" = \"\"";
	} else {
		userlist.filter=filterCol+" = *"+value+"*";
	}
	hideFilterMenu();
	userlist.Reset();
}

</SCRIPT>
<DIV ID="oFilterMenu" style="position:absolute;background-color:#ffffff;border-width:2;border-color:#000000;border-style:solid;padding: 2px; font-size:x-small;display:none" onclick="window.event.cancelBubble = true;">
			<form>
			<table border="0" style="font-size:x-small">
			<thead>
			<th align="center">�ֶι���</th>
			</thead>
			<tr>
			<td nowrap>
			���ֶ�Ӧ������<input type="text" id="oFilterValue" name="filterValue">
			</td>
			</tr>
			<tr>
			<td align="center">
			<input type="button" onclick="doFilter(oFilterValue.value);" value="Ӧ�ù�������">
			</td>
			</tr>
			</table>
			</form>
</DIV>

<DIV align="center">
<table border="1" datasrc="#userlist" id="oUserInfo" width="99%">
<thead>
<TH><span onclick="return sort('account');" oncontextmenu="filter('account');" class="userAccount" onmouseover="this.className='userAccount_on';" onmouseout="this.className='userAccount';">�˺�</span><span id="oSortOn_account"></span></th>
<TH><span onclick="return sort('name');"  oncontextmenu="filter('name');" class="userAccount" onmouseover="this.className='userAccount_on';" onmouseout="this.className='userAccount';">����</span><span id="oSortOn_name"></span></th>
<TH><span onclick="return sort('unit');"  oncontextmenu="filter('unit');" class="userAccount" onmouseover="this.className='userAccount_on';" onmouseout="this.className='userAccount';">��λ</span><span id="oSortOn_unit"></span></th>
<TH><span onclick="return sort('department');"  oncontextmenu="filter('department');" class="userAccount" onmouseover="this.className='userAccount_on';" onmouseout="this.className='userAccount';">����</span><span id="oSortOn_department"></span></th>
</thead>
<tbody>
<td onclick="return chooseUser()" class="userAccount" onmouseover="this.className='userAccount_on';" onmouseout="this.className='userAccount';"><span datafld="account"></span></td>
<td><span datafld="name"></span></td>
<td><span datafld="unit"></span></td>
<td><span datafld="department"></span></td>
</tbody>
</table>
</div>
<SCRIPT language="JScript">
sort('account');
</script>
</BODY>
</HTML>