#!/bin/bash

#========================================#
# 					 #
#	  NAME : myool		         #
#	AUTHOR : cle0n		         #
#      VERSION : v2.0		         #
#      PURPOSE : Hide a file in PDF      #
#		 without a blank page.	 #
# 				  	 #
#========================================#

# NOTE: MUST HAVE >> pdftk << INSTALLED 

# USAGE hide   : myool.sh hide [file to hide] [targetpdf] 
# USAGE reveal : myool.sh reveal [targetpdf]

if [ "$1" == "hide" ]; then
    
    # get the filename which includes the extension
    filetohide=$(basename "$2")
    targetpdf=$(basename "$3")

    #uncompress
    pdftk $targetpdf output uncomp.pdf uncompress

    sed -i '0,/endstream/s//72656269727468/' uncomp.pdf
    xxd -p $filetohide | sed -i -e '/^72656269727468/ r /dev/stdin' -i -e '// a endstream' uncomp.pdf

    #fix xref
    pdftk uncomp.pdf output fixref.pdf

    #compress
    pdftk fixref.pdf output final.pdf compress

    rm uncomp.pdf
    rm fixref.pdf

elif [ "$1" == "reveal" ]; then 

    targetpdf=$(basename "$2")

    #uncompress
    pdftk $targetpdf output uncomp.pdf uncompress

    sed -e '1,/72656269727468/d' -e '/endstream/,$d' uncomp.pdf | xxd -r -p > outfile

    rm uncomp.pdf

else

    echo "USAGE hide   : myool.sh hide [file to hide] [targetpdf]" 
    echo "USAGE reveal : myool.sh reveal [targetpdf]"

fi
