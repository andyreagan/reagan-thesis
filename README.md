From Josh's version I've added some functionality through scripts, reorganized, and made the default more thesis-oriented.

TLDR: run "./setup.sh my-dissertation", edit away, compile w "./make-dissertation.sh"

Mainly, it's just more set up for making a standard style thesis (as opposed to a journal article thesis).
Both functionalities are included in the dissertation.tex file, and both sets of tex files for the chapters are included.
Running ./make-dissertation.sh makes either format, specified by the variable STYLE.

I've also included a few files for catching common writing errors, as detailed in http://matt.might.net/articles/shell-scripts-for-passive-voice-weasel-words-duplicates/ and brought to our attention by Chris Danforth.
These run by default in make-dissertation.sh and their usage is otherwise documented in bin.

Cheers,
Andy

-------------------------------------------

This is a LaTeX style file for typesetting a UVM thesis or dissertation in compliance with the guideline of the Graduate College.  The package is free software, available under the terms of the Academic Free License version 2.0.

I, Joshua Auerbach, adapted this from materials provided by David Van Horn (see http://www.cs.brandeis.edu/~dvanhorn/uvmlatexthesis/ and text below)

I have updated David's file to comply with the current guidelines (As of Spring semester 2013, see http://www.uvm.edu/~gradcoll/pdf/Guidelines%20for%20Writing%20and%20Defending%20Thesis%20and%20Disseration.pdf)
and to allow for journal format dissertations, but you will still need to bring a copy of your thesis to the Graduate College for a format review, and they may require you to make small changes. 

See dissertation.tex for an example and more details.

Use make-dissertation.sh to compile (this has some special logic for creating the per chapter reference sections)

Hope this is somewhat helpful.  Following David's initial remarks I welcome comments, questions, and improvements on this package. If your thesis uses this style, I'd really appreciate a notice. 
---Josh

------------------------------------------

David's original notice:

This is a LaTeX style file for typesetting a graduate thesis in compliance with the guidelines of the Graduate College of the University of Vermont. The package is free software, available under the terms of the Academic Free License version 2.0.

caveat emptor: You will still need to bring a copy of your thesis to the Graduate College for a format review, and they may require you to make small changes. Several people have taken a thesis using this style for review. Each time, different minor changes are requested by the reviewer. So, the process is not totally consistent, but this package should save you significant work. Send me any changes requested by the Graduate College and I will incorporate them into the style to save others the hassle.

I welcome comments, questions, and improvements on this package. If your thesis uses this style, I'd really appreciate a notice. ---David
