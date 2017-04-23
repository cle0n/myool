#!/bin/bash

#========================================#
#                                 __     #
#    .--------.--.--.-----.-----.|  |    #
#    |        |  |  |  _  |  _  ||  |    #
#    |__|__|__|___  |_____|_____||__|    #
#             |_____|                    #
#                                        #
#========================================#
# Version: 3 ?
# AUTHOR: cle0n
# Description: Encrypt a file. Split it up. Scramble the chunks and hide it in any PDF
# Requires: pdftk
# Tested on Ubuntu, Debian

# : The EOF on enc.data and unenc.data are different. gpg issues a warning before it decrypts.

########################-->        USAGE       <--########################

usage() {
    echo "USAGE hide   : myool.sh hide [file to hide] [targetpdf]" 
    echo "USAGE reveal : myool.sh reveal [targetpdf]"
}

##########################--> GET INCREMENTOR <--#########################

get_incrementor() {
    local e_count=$1
    local newlines=$2

    incrementor=$((newlines / e_count))

    if [ $newlines -lt $e_count ]; then
        # return 1 = no split.
        echo 1
        return
    fi

    echo $incrementor
}


########################--> LOCATE ENTRY POINTS <--########################

locate_entry_points() {

    local array

    array+=(`grep -an '/Subtype /Image' uncomp.pdf | cut -d ':' -f1 `)
    array+=(`grep -an '/Subtype /Type1C' uncomp.pdf | cut -d ':' -f1 `)
    array+=(`grep -an '/BitsPerSample' uncomp.pdf | cut -d ':' -f1 `)
    if [ -z $array ]; then
        echo 1
        return
    fi

    local endstream=(`grep -an 'endstream' uncomp.pdf | cut -d ':' -f1 `)
    local es_count=0

    local arrayc=${#array[*]}
    local index=0

    array=(`echo ${array[*]} | tr ' ' '\n' | sort -n | tr '\n' ' '`)

    while [ $index -lt $arrayc ]; do
	if [ ${array[$index]} -lt ${endstream[$es_count]} ]; then
            newerarray+=(${endstream[$es_count]})
            index=$((index + 1))
	fi
        es_count=$((es_count + 1))
    done

    newerarray=(`shuf -e ${newerarray[*]} | tr "\n" " "`)

    local newlines=`wc -l enc.data | cut -d ' ' -f1`
    incrementor=$(get_incrementor $arrayc $newlines)

    for (( i=0; i<${arrayc}-1; i++ ));
    do
        for (( j=${i}; j<${arrayc}-1; j++ ));
        do
            if [ ${newerarray[$j+1]} -gt ${newerarray[$i]} ]; then
                ((newerarray[$j+1]+=$incrementor+1))
            fi
        done
    done

    echo $incrementor $arrayc $newlines ${newerarray[*]}
}

########################-->        HIDE        <--########################

hide() {
    filetohide=$(basename "$2")
    targetpdf=$(basename "$3")
    key="6d796f6f6c"

    echo "[*] Encrypting data"
    gpg --output enc.data --symmetric --cipher-algo AES256 $filetohide 2> /dev/null

    if [ "$?" != 0 ]; then
	echo "[-] Passwords don't match."
	exit
    fi

    echo "[*] Overwriting gpg file signature"
    ranbytes=`xxd -l 6 /dev/urandom | cut -d ' ' -f2,3,4 | tr -d ' '`
    echo -n "0: $ranbytes" | xxd -r - enc.data

    echo "[*] Uncompressing target pdf"
    pdftk $targetpdf output uncomp.pdf uncompress

    echo "[*] Calculating entry points..."
    read incrementor e_count newlines entrypoints < <(locate_entry_points)
    entrypoints=($entrypoints)

    if [ $entrypoints -eq 1 ]; then
	echo "[-] No safe entrypoints found. Injecting everything into first stream..."
	sed -i '0,/endstream/s//'"$key"'/' uncomp.pdf
	sed -i -e '/'"$key"'/ r enc.data' -e '// a endstream' uncomp.pdf
    else
	echo "[+] Entry points located. Injecting..."

        index=0
        startblock=1
        endblock=$((startblock+incrementor-1))
        entry=${entrypoints[$index]}

        # faster way to use sed here?
        while [ $index -lt $e_count ]; do
            sed -i \
                ''"$entry"' {
                    s/endstream/'"$key"''"$index"'/
                    a endstream
                    p
                    s/'"$key"''"$index"'/sed '"$startblock"','"$endblock"'!d enc.data/e
                }' uncomp.pdf

            ((index++))
            ((entry=entrypoints[index]))
            ((startblock=endblock+1))
            ((endblock=endblock+incrementor))

            if [ $index -eq $((e_count-1)) ]; then
                ((endblock+=99999))
            fi
        done
    fi

    rm enc.data

    echo "[*] Compressing. This may take while..."
    pdftk uncomp.pdf output enc-$targetpdf compress

    rm uncomp.pdf
}

########################-->       REVEAL       <--########################

reveal() {
    targetpdf=$(basename "$2")
    key="6d796f6f6c"
    index=0

    echo "[*] Uncompressing target pdf"
    pdftk $targetpdf output uncomp.pdf uncompress

    count=`grep -a $key uncomp.pdf | wc -l`

    echo "[*] Attemping data extraction"
    while [ $index -lt $count ]; do
        sed '1,/'"$key"''"$index"' /d;/endstream/,$d' uncomp.pdf >> unenc.data
        ((index++))
        truncate -s -1 unenc.data
    done

    echo "[*] Rewriting gpg file signature"
    gpgsig="8c0d04090302"
    echo -n "0: $gpgsig" | xxd -r - unenc.data

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
