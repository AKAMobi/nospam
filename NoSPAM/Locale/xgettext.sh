#!/bin/sh

	#--add-comments=TRANSLATORS: --files-from=./POTFILES.in \

xgettext --output=./engine.nospam.cn.pot \
	--copyright-holder="Imperia AG Huerth/Germany" \
	--from-code=GBK \
	--keyword --keyword='$__' --keyword=__ --keyword=__x \
	--keyword=__n:1,2 --keyword=__nx:1,2 --keyword=__xn \
	--keyword=N__ --language=perl $@ && \
	\
	msgmerge engine.nospam.cn.po engine.nospam.cn.pot -o engine.nospam.cn.pox && \
	\
	rm -f engine.nospam.cn.pot engine.nospam.cn.po && \
	mv engine.nospam.cn.pox engine.nospam.cn.po &&
	\
	msgfmt engine.nospam.cn.po -o engine.nospam.cn.mo && \
	\
	mv -f engine.nospam.cn.mo /home/NoSPAM/LocaleData/zh_CN/LC_MESSAGES 

#iconv -f utf8 -t GBK engine.nospam.cn.pot 
