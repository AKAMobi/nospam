SRC_FILES=../Lib/AKA/*.pm ../Lib/AKA/Mail/*.pm ../Bin/NoSPAM.pl

all:
	make pot
	make merge
	make po
	make mo

test:
	echo ${SRC_FILES}
	exit;
	for srcfile in ${SRC_FILE} ; \
	do \
		xgettext --output=./engine.nospam.cn.pot \
			--copyright-holder="AKA Information & Technology Co., Ltd" \
			--from-code=GBK \
			--keyword --keyword='$__' --keyword=__ --keyword=__x \
			--keyword=__n:1,2 --keyword=__nx:1,2 --keyword=__xn \
			--keyword=N__ --language=perl ${srcfile} 
		if [ -f engine.nospam.cn.pot ]; then \
			msgmerge engine.nospam.cn.po engine.nospam.cn.pot -o engine.nospam.cn.pox \
			rm -f engine.nospam.cn.pot engine.nospam.cn.po
			mv engine.nospam.cn.pox engine.nospam.cn.po
		fi 
	done
	

pot:
	xgettext --output=./engine.nospam.cn.pot \
	--copyright-holder="AKA Information & Technology Co., Ltd" \
	--from-code=GBK \
	--keyword --keyword='$__' --keyword=__ --keyword=__x \
	--keyword=__n:1,2 --keyword=__nx:1,2 --keyword=__xn \
	--keyword=N__ --language=perl ${SRC_FILES} 

merge:
	msgmerge engine.nospam.cn.po engine.nospam.cn.pot -o engine.nospam.cn.pox

po:
	rm -f engine.nospam.cn.pot engine.nospam.cn.po
	mv engine.nospam.cn.pox engine.nospam.cn.po

mo:
	msgfmt engine.nospam.cn.po -o engine.nospam.cn.mo

install:
	mv -f engine.nospam.cn.mo /home/NoSPAM/LocaleData/zh_CN/LC_MESSAGES 

#
