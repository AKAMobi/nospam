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
	if(confirm("�����������ݣ�ȷ����"))
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
