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

# This version of myool attempts to fix the XREF table of the pdf without pdftk. It works but takes too long. Might as well just use pdftk 


# patching the xref is one line
# fix problem with object not inserting into the last stream
# use wc -m not wc -c
# probably don't even need to fix the xref table...

############################--> PATCH XREF <--############################

function patch_xref {

    local line=`grep -an 'xref' uncomp.pdf`
    local xref=`echo $line | awk '{print $1}' | cut -d ':' -f1`
    local startxref=`echo $line | awk '{print $2}' | cut -d ':' -f1`
    local off=$1
    local size=$2
    local xrefsize=`sed -e '1,/xref/d' -e '/trailer/,$d' uncomp.pdf | wc -l`
    #local xrefsize=`sed -e '1,/xref/d' -e '/trailer/,$d' data | cat -n | tail -n 1 | awk '{ print $1}'`

    
    while [ "$off" -le "$xrefsize" ]; do
	sed -i -e ''"$((xref + off))"'s/0*//' -i -e ''"$((xref + off))"'s/[0-9]*/echo $((&+'"$size"'))/e' uncomp.pdf 
	sed -i -r -e ''"$((xref + off))"'s/[0-9]/000000000&/' -i -e ''"$((xref + off))"'s/0*([0-9]{10}[^0-9])/\1/' uncomp.pdf 
	off=$((off + 1))
    done

    #local val=`sed -n '/startxref/{n:p}' uncomp.pdf`
    sed -i '/startxref/{n;s/.*/echo $((& + '"$size"'))/e}' uncomp.pdf 


}


########################--> LOCATE OBJ NUMBER <--#########################

function get_obj {

    local i=0
    local dope=(`grep -an '.*[0-9] obj' uncomp.pdf | awk '{print $1}'`)

    while true; do
	if [ `cut -d ':' -f1 <<< ${dope[$i]}` -gt "$1" ]; then
	    i=$((i - 1))
	    cut -d ':' -f2 <<< ${dope[$i]}
	    break
	fi
	i=$((i + 1))
    done

}


########################--> LOCATE ENTRY POINT <--########################

function locate_entry_point {
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

    # es_count=`echo ${endstream[*]} | wc -w`
    # let es_count="$es_count - 1"
    local es_count=0

    fire_count=`echo ${fire[*]} | wc -w`
    let fire_count="$fire_count - 1"

    local obj

    while true; do
	if [ "${fire[$fire_count]}" -lt "${endstream[$es_count]}" ]; then
	    break
	else
	    es_count=$((es_count + 1))
	fi
    done

    obj=$(get_obj ${fire[$fire_count]})

    echo ${endstream[$es_count]} $obj
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
    entrypoint=`cut -d ' ' -f1 <<< $entrypoint`
    obj=`cut -d ' ' -f2 <<< $entrypoint`

    if [ "$entrypoint" == 1 ]; then
	echo "[-] No safe entrypoint found. Injecting into first stream..."
	sed -i '0,/endstream/s//firefirefire/' uncomp.pdf
	xxd -p enc.data | tr -d '\n' | sed -i -e '/firefirefire/ r /dev/stdin' -i -e '// a endstream' uncomp.pdf
    else
	echo "[+] Entry point located. Injecting..."
	xxd -p enc.data | sed -i -e ''"${entrypoint}"'s/endstream/firefirefire/' -i -e '/firefirefire/ r /dev/stdin' -i -e '// a endstream' uncomp.pdf
    fi

    rm enc.data

    echo "[*] Fixing the XREF."
    size=`wc -c $filetohide`
    patch_xref $obj $size
    #pdftk uncomp.pdf output fixref.pdf
    #rm uncomp.pdf

    echo "[*] Compressing. This may take while..."
    pdftk uncomp.pdf output enc-$targetpdf compress
    rm uncomp.pdf
    #pdftk fixref.pdf output enc-$targetpdf compress
    #rm fixref.pdf


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
