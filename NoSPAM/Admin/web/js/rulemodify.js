function changeState(name)
{
	state = name.disabled;
	if(state)
		name.disabled=false;
	else
		name.disabled=true;
}

function confirmReset()
{
	if(confirm("重置所有数据，确定吗？"))
		document.ParamForm.reset();
}

function submitForm(param)
{
	if(param == 'save')
		if(!checkParams())
			return false;

	d1 = new Date(0);
	d1.setFullYear(document.all.expireYear.value);
	d1.setMonth(document.all.expireMonth.value-1);
	d1.setDate(document.all.expireDate.value);
	d1.setHours(document.all.expireHour.value);
	document.ParamForm.expire_time.value = d1.valueOf();
	document.ParamForm.formAction.value=param;
	document.ParamForm.submit();
}

function checkParams()
{
	return true;
}

function initSelect()
{
	year = d.getFullYear();
	month = d.getMonth();
	date = d.getDate();
	hour = d.getHours();

	for(i=2000;i<=2020;i++){
		var oOption = document.createElement("option");
		oOption.text = i;
		oOption.value = i;
		document.all.expireYear.add(oOption);
		if(i == year){
			oOption.selected = true;
		}
	}

	for(i=0;i<=11;i++){
		var oOption = document.createElement("option");
		oOption.text = i+1;
		oOption.value = i+1;
		document.all.expireMonth.add(oOption);
		if(i == month){
			oOption.selected = true;
		}
	}

	MaxDate = genDate(year,month);
	for(i=1;i<=MaxDate;i++){
		var oOption = document.createElement("option");
		oOption.text = i;
		oOption.value = i;
		document.all.expireDate.add(oOption);
		if(i == date){
			oOption.selected = true;
		}
	}
	
	for(i=0;i<=23;i++){
		var oOption = document.createElement("option");
		oOption.text = i;
		oOption.value = i;
		document.all.expireHour.add(oOption);
		if(i == hour){
			oOption.selected = true;
		}
	}
	//document.all.eHour.options(0).selected= true;
}

function genDate(iYear, iMonth)
{
	switch(iMonth){
		case 0:
		case 2:
		case 4:
		case 6:
		case 7:
		case 9:
		case 11:
		return 31;
		break;
		case 3:
		case 5:
		case 8:
		case 10:
		return 30;
		break;
		case 1:
		return isLeapYear(iYear)? 29:28;
		break;
	}
}

function isLeapYear(iYear)
{
	if(isNaN(iYear))
		return false;

	if( (iYear%100 == 0) && (iYear%400 != 0) )
		return false;
	
	if( iYear%4 != 0)
		return false;
	
	return true;
}

function recalcDate(flag)
{
	y = document.all.expireYear.value;
	m = document.all.expireMonth.value;
	oDate = document.all.expireDate;

	l = oDate.children.length;
	date = oDate.value;
	for(i = 0;i<l;i++)
		oDate.removeChild(oDate.children(0));

	MaxDate = genDate(y,m-1);
	for(i=1; i<= MaxDate; i++){
		var oOption = document.createElement("option");
		oOption.text = i;
		oOption.value = i;
		oDate.add(oOption);
		if(i == date)
			oOption.selected = true;
	}
}

function changeExpire()
{
	aSelects = document.getElementsByTagName("select");

	for (i = 0; i <aSelects.length; i++)
	{
		if (aSelects[i].name.indexOf("expire") != -1)
		{
			aSelects[i].disabled = !event.srcElement.checked;
		}
	}
}
