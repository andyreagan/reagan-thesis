#!/bin/bash

FILENAME_BASE="reagan-thesis"

# set STYLE to JA for a journal article style thesis
#      (and set the \input's to \include's in the main)
STYLE="standard"

# first test the body versus our style scripts
for FILE in $FILENAME_BASE.chapter*-$STYLE.tex
do
  echo "checking $FILE"
  perl bin/lexical-illusion-spotter.pl $FILE
  bin/weasel-word-spotter.sh $FILE
  bin/passive-word-spotter.sh $FILE
done

pdflatex $FILENAME_BASE-main;

if [ $STYLE == "JA" ]; then
  for auxfile in $FILENAME_BASE.chapter*-JA.aux
  do
      bibtex `basename $auxfile .aux`
  done
  
  for bblfile in $FILENAME_BASE.chapter*-JA.bbl
  do
          sed -i 's/thebibliography/references/' $bblfile
  done
fi

bibtex $FILENAME_BASE-main;
pdflatex $FILENAME_BASE-main;
pdflatex $FILENAME_BASE-main;
pdflatex $FILENAME_BASE-main;


