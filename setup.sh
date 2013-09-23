#!/bin/bash
#
# set up these files for YOUR disseration!
#
# USAGE:
# ./setup.sh reagan-thesis

OLD_NAMEBASE="doe-dissertation"
NEW_NAMEBASE=$1

for FILE in *.tex
do
  mv $FILE $(echo $FILE | sed s/$OLD_NAMEBASE/$NEW_NAMEBASE/)
done

\rm $OLD_NAMEBASE*

sed -i .old s/$OLD_NAMEBASE/$NEW_NAMEBASE/ $NEW_NAMEBASE-main.settings.tex

sed -i .old s/$OLD_NAMEBASE/$NEW_NAMEBASE/ make-dissertation.sh

\rm *.old