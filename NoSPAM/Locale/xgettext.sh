#!/bin/sh

	#--add-comments=TRANSLATORS: --files-from=./POTFILES.in \

xgettext --output=./engine.pot \
	--copyright-holder="Imperia AG Huerth/Germany" \
	--from-code=GBK \
	--keyword --keyword='$__' --keyword=__ --keyword=__x \
	--keyword=__n:1,2 --keyword=__nx:1,2 --keyword=__xn \
	--keyword=N__ --language=perl $@ && \
	msgmerge engine.po engine.pot -o engine.pox && \
	rm -f engine.pot engine.po && \
	mv engine.pox engine.po

