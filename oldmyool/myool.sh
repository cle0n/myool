#!/bin/bash

#========================================#
# 					 #
#	  NAME : myool		         #
#	AUTHOR : cle0n			 #
#      VERSION : v1.01		         #
#      PURPOSE : Hide a file in PDF      #
# 				  	 #
#========================================#

# NOTE: MUST HAVE >> pdftk << INSTALLED 

# USAGE hide   : myool.sh hide [file to hide] [targetpdf] 
# USAGE reveal : myool.sh reveal [targetpdf]

if [ "$1" == "hide" ]; then
    file=$2
    attachpdf=$3

    # get the filename which includes the extension
    filename=$(basename "$file")

    # create temporary template based on PAGE.PDF
    cp "/usr/local/bin/page.pdf" insert.pdf

    # attach the file to PAGE.PDF and output the result to a new PDF (ATTACHEDTEMP.PDF)
    pdftk "/usr/local/bin/page.pdf" attach_files "$file" output attachedtemp.pdf
    # uncompress ATTACHEDTEMP.PDF and output the result to a new PDF (UNCOMP.PDF) (the file needs to be uncompressed for editing)
    pdftk attachedtemp.pdf output uncomp.pdf uncompress

    rm attachedtemp.pdf

    # extract everything between "stream" and "endstream" (i.e. the data) from UNCOMP.PDF and redirect it to a temporary txt file
    # in addition, the following command replaces all "('s" with BLEEEEEP and all ")'s" with BLOOOOORP in order to prevent unbalanced parentheses
    sed -e '1,/stream/d' -e '/endstream/,$d' -e 's/(/BLEEEEEP/g' -e 's/)/BLOOOOORP/g' uncomp.pdf > holdme.txt
    
    rm uncomp.pdf
    
    # insert the data from holdme.txt (stdout) into the temporary template INSERT.PDF after "stream"
    # (  BT  ) begin text stream
    # (  /F1 1  ) sets the font and font size
    # (  Tf 9999 9999  ) sets the cursor position at x and y, which you can tell is way off the page
    # (  Td (...  ) begins the text block
    #
    # (  '"\n$filename\n"'HIDDENFILE' -i -e '// r /dev/stdin' -i -e '// a HIDDENEND) Tj ET  ) : 
    #	    1. inserts a newline, adds the filename, inserts a newline,
    #	    2. inserts "HIDDENFILE" (identifier),
    #	    3. inserts the data from "cat holdme.txt" (i.e. stdin),
    #	    4. lastly inserts "HIDDENEND) Tj ET". (Tj - ends the text block, ET - ends the text stream)
    # 
    cat holdme.txt | sed -i -e '/^stream/ a BT /F1 1 Tf 9999 9999 Td ('"\n$filename\n"'HIDDENFILE' -i -e '// r /dev/stdin' -i -e '// a HIDDENEND) Tj ET' insert.pdf

    rm holdme.txt

    # need to correct the XREF table, then compress it.
    pdftk insert.pdf output temp.pdf
    pdftk temp.pdf output comp.pdf compress

    # the last step is to append the the compressed PDF to another PDF as the last page.
    pdftk "$attachpdf" comp.pdf cat output /home/${USER}/Desktop/ayy.pdf

    rm insert.pdf
    rm temp.pdf
    rm comp.pdf
elif [ "$1" == "reveal" ]; then 
    pdffile=$2

    # uncompress PDF and output result to a temporary PDF (need to uncompress inorder to edit text properly)
    pdftk $pdffile output $pdffile.tmp uncompress

    # the following command removes all the pages but the last and outputs the result to NEW.PDF
    pdftk $pdffile.tmp cat end output new.pdf

    # get the filename that was inserted before "HIDDENFILE" identifier
    filename=$(grep -ia -B 1 'HIDDENFILE' new.pdf | sed 's/HIDDENFILE.*//')

    # extract text(data) between "HIDDENFILE" and "HIDDENEND", return the brackets, and finally redirect that to the filename.
    sed -e '1,/HIDDENFILE/d' -e '/HIDDENEND/,$d' -e 's/BLEEEEEP/(/g' -e 's/BLOOOOORP/)/g' new.pdf > "/home/${USER}/Desktop/${filename}"

    rm $pdffile.tmp
    rm new.pdf
else
    echo "USAGE hide   : myool.sh hide [file to hide] [targetpdf]" 
    echo "USAGE reveal : myool.sh reveal [targetpdf]"
fi
