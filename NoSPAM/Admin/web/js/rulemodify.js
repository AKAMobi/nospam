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
	document.ParamForm.formAction.value=param;
	document.ParamForm.submit();
}

function checkParams()
{
	return true;
}
