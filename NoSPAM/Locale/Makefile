SRC_FILES=../Lib/AKA/*.pm ../Lib/AKA/Mail/*.pm ../Bin/NoSPAM.pl

all:
	make web_filelist
	make engine_pot
	make web_pot
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
	
web_filelist:
	find ../Admin/web -type f -name "*.ns" > web.file.list

web_pot:
	xgettext --output=./web.nospam.cn.pot \
	--copyright-holder="AKA Information & Technology Co., Ltd" \
	--from-code=GBK \
	--keyword=_ --language=PHP --files-from=web.file.list 
#	rm -f web.file.list


engine_pot:
	xgettext --output=./engine.nospam.cn.pot \
	--copyright-holder="AKA Information & Technology Co., Ltd" \
	--from-code=GBK \
	--keyword --keyword='$__' --keyword=__ --keyword=__x \
	--keyword=__n:1,2 --keyword=__nx:1,2 --keyword=__xn \
	--keyword=N__ --language=perl ${SRC_FILES} 

merge:
	msgmerge engine.nospam.cn.po engine.nospam.cn.pot -o engine.nospam.cn.pox
	msgmerge web.nospam.cn.po web.nospam.cn.pot -o web.nospam.cn.pox

po:
	rm -f engine.nospam.cn.pot engine.nospam.cn.po
	rm -f web.nospam.cn.pot web.nospam.cn.po
	mv engine.nospam.cn.pox engine.nospam.cn.po
	mv web.nospam.cn.pox web.nospam.cn.po

mo:
	msgfmt engine.nospam.cn.po -o engine.nospam.cn.mo
	msgfmt web.nospam.cn.po -o web.nospam.cn.mo

install:
	mv -f engine.nospam.cn.mo /home/NoSPAM/LocaleData/zh_CN/LC_MESSAGES 
	mv -f web.nospam.cn.mo /home/NoSPAM/LocaleData/zh_CN/LC_MESSAGES 

