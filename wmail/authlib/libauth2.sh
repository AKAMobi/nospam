
# $Id$

while read L
do
	LL=`echo $L | tr '/.-' 'AB_'`

	var='flag=`echo x$flag'$LL'`'
	eval $var
	if test "$flag" = "x"
	then
		var="flag$LL"=1
		eval $var

		case "$L" in
		-*)
			libs="$libs $L"
			;;
		*)
			mods="$mods $L"
			;;
		esac
	fi
done

echo $libs $mods | tr ' ' '\012'
