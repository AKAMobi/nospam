
# $Id$

while read L
do
   REVLIST="$L $REVLIST"
done
echo $REVLIST | tr ' ' '\012'
