#!/bin/bash

#========================================#
# 					 #
#	  NAME : myool		         #
#	AUTHOR : cle0n		         #
#      VERSION : v2.02		         #
#      PURPOSE : Hide an encrypted file  #
#		 in a PDF		 #
# 				  	 #
#========================================#

# NOTE: MUST HAVE >> pdftk << INSTALLED 


########################--> LOCATE ENTRY POINT <--########################

function locate_entry_point {
    local i=0
    local fire

    local image=(`grep -an '/Subtype /Image' uncomp.pdf | cut -d ':' -f1 `)
    fire=$image

    if [ -z $image ]; then
	local typec=(`grep -an '/Subtype /Type1C' uncomp.pdf | cut -d ':' -f1 `)
	fire=$typec
	if [ -z $typec ]; then
	    local bits=(`grep -an '/BitsPerSample' uncomp.pdf | cut -d ':' -f1 `)
	    fire=$bits
	    if [ -z $bits ]; then
		echo 1
		return
	    fi
	fi
    fi

    local endstream=(`grep -an 'endstream' uncomp.pdf | cut -d ':' -f1 `)

    while true; do
	if [ "${fire[0]}" -lt "${endstream[$i]}" ]; then
	    break
	else
	    i=$((i + 1))
	fi
    done
    echo ${endstream[$i]}
}

###########################################################################
#                                - BEGIN -                                #
###########################################################################
if [ "$1" == "hide" ]; then
    
    # get the filename which includes the extension
    filetohide=$(basename "$2")
    targetpdf=$(basename "$3")

    echo "[*] Encrypting data"
    gpg --output enc.data --symmetric --cipher-algo AES256 $filetohide 2> /dev/null

    if [ $? != 0 ]; then
	echo "[-] Passwords don't match."
	exit
    fi

    echo "[*] Uncompressing target pdf"
    pdftk $targetpdf output uncomp.pdf uncompress

    echo "[*] Finding entry point ..."
    entrypoint=$(locate_entry_point)

    if [ "$entrypoint" == 1 ]; then
	echo "[-] No safe entrypoint found. Injecting into first stream..."
	sed -i '0,/endstream/s//firefirefire/' uncomp.pdf
	xxd -p enc.data | tr -d '\n' | sed -i -e '/firefirefire/ r /dev/stdin' -i -e '// a endstream' uncomp.pdf
    else
	echo "[+] Entry point located. Injecting..."
	xxd -p enc.data | sed -i -e ''"${entrypoint}"'s/endstream/firefirefire/' -i -e '/firefirefire/ r /dev/stdin' -i -e '// a endstream' uncomp.pdf
    fi

    rm enc.data

    echo "[*] Fixing the XREF. This may take while..."
    pdftk uncomp.pdf output fixref.pdf
    rm uncomp.pdf

    echo "[*] Compressing"
    pdftk fixref.pdf output enc-$targetpdf compress
    rm fixref.pdf


elif [ "$1" == "reveal" ]; then 

    targetpdf=$(basename "$2")

    echo "[*] Uncompressing target pdf"
    pdftk $targetpdf output uncomp.pdf uncompress

    echo "[*] Attemping data extraction"
    #sed -e '1,/72656269727468/d' -e '/endstream/,$d' uncomp.pdf | sed -e "s/.\{60\}/&\n/g" | xxd -r -p > unenc.data
    sed -e '1,/firefirefire/d' -e '/endstream/,$d' uncomp.pdf | xxd -r -p > unenc.data
    rm uncomp.pdf

    echo "[*] Decrypting data"
    gpg --output outfile --decrypt unenc.data 2> /dev/null

    if [ $? != 0 ]; then
	echo "[-] You entered the wrong password. Nothing decrypted"
    else
	rm unenc.data
    fi

else

    echo "USAGE hide   : myool.sh hide [file to hide] [targetpdf]" 
    echo "USAGE reveal : myool.sh reveal [targetpdf]"

fi
