#!/bin/bash

#========================================#
#                                 __     #
#    .--------.--.--.-----.-----.|  |    #
#    |        |  |  |  _  |  _  ||  |    #
#    |__|__|__|___  |_____|_____||__|    #
#             |_____|                    #
#                                        #
#========================================#
# Version 2.4
# AUTHOR: cle0n
# Description: Encrypt a file and hide it in any PDF
# Dependancies: pdftk

# ISSUE: The EOF on enc.data and unenc.data are different. gpg therefore issues a warning before it decrypts.

# Faster than current version (3?) because it doesn't have multiple entry points. thus multiples sed invocations.

########################-->        USAGE       <--########################

usage() {
    echo "USAGE hide   : myool.sh hide [file to hide] [targetpdf]" 
    echo "USAGE reveal : myool.sh reveal [targetpdf]"
}

########################--> LOCATE ENTRY POINT <--########################

locate_entry_point() {

    local array

    local image=(`grep -an '/Subtype /Image' uncomp.pdf | cut -d ':' -f1 `)
    array=(${image[*]})

    if [ -z $image ]; then
	local typec=(`grep -an '/Subtype /Type1C' uncomp.pdf | cut -d ':' -f1 `)
	array=(${typec[*]})
	if [ -z $typec ]; then
	    local bits=(`grep -an '/BitsPerSample' uncomp.pdf | cut -d ':' -f1 `)
	    array=(${bits[*]})
	    if [ -z $bits ]; then
		echo 1
		return
	    fi
	fi
    fi

    local endstream=(`grep -an 'endstream' uncomp.pdf | cut -d ':' -f1 `)
    local es_count=0

    local arrayc=`wc -w <<< ${array[*]}`
    let local count="$arrayc - 1"

    while true; do
	if [ "${array[$count]}" -lt "${endstream[$es_count]}" ]; then
	    break
	fi
	es_count=$((es_count + 1))
    done

    echo ${endstream[$es_count]}
}

########################-->        HIDE        <--########################

hide() {
    filetohide=$(basename "$2")
    targetpdf=$(basename "$3")

    echo "[*] Encrypting data"
    gpg --output enc.data --symmetric --cipher-algo AES256 $filetohide 2> /dev/null

    if [ "$?" != 0 ]; then
	echo "[-] Passwords don't match."
	exit
    fi

    echo "[*] Uncompressing target pdf"
    pdftk $targetpdf output uncomp.pdf uncompress

    echo "[*] Finding entry point ..."
    entrypoint=$(locate_entry_point)

    if [ "$entrypoint" == 1 ]; then
	echo "[-] No safe entrypoint found. Injecting into first stream..."
	sed -i '0,/endstream/s//6d796f6f6c/' uncomp.pdf
	sed -i -e '/6d796f6f6c/ r enc.data' -e '// a endstream' uncomp.pdf
    else
	echo "[+] Entry point located. Injecting..."
	sed -i -e ''"${entrypoint}"'s/endstream/6d796f6f6c/' -e '/6d796f6f6c/ r enc.data' -e '// a endstream' uncomp.pdf
    fi

    rm enc.data

    echo "[*] Compressing. This may take while..."
    pdftk uncomp.pdf output enc-$targetpdf compress

    rm uncomp.pdf
}

########################-->       REVEAL       <--########################

reveal() {
    targetpdf=$(basename "$2")

    echo "[*] Uncompressing target pdf"
    pdftk $targetpdf output uncomp.pdf uncompress

    echo "[*] Attemping data extraction"
    sed -e '1,/6d796f6f6c/d' -e '/endstream/,$d' uncomp.pdf > unenc.data
    rm uncomp.pdf

    echo "[*] Decrypting data"
    gpg --output outfile --decrypt unenc.data 2> /dev/null

    rm unenc.data
}

########################-->        MAIN        <--########################

main() {
    if [ "$1" == "hide" ]; then hide $@;
    elif [ "$1" == "reveal" ]; then reveal $@;
    else usage; fi
}

main $@
