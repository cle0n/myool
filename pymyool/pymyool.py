import os
import re
import sys
import random
from subprocess import Popen

# TODO: error checking
# TODO: payload encryption/encoding
# TODO: patch xref
# TODO: usage

# usage: python myool.py [hide|reveal] [datatohide] targetpdf

# uncompress -> compress -> package -> patch xref ?

KEY = 'Blu3ceLL'

def ProcessContraband(datafile, arraysize):

    dataSize = os.stat(datafile).st_size
    BUFFER = dataSize / arraysize
    print '  Entrypoints\t  : %d' % arraysize
    print '  Input Data Size : %d' % dataSize
    print '  Chunk Size\t  : %d\n' % BUFFER
    
    with open(datafile, 'r+b') as data:
        d_array = []
        while True:
            chunk = data.read(BUFFER)
            if not chunk: break
            d_array.append(chunk)

        if len(d_array) > arraysize:
            d_array[arraysize - 1] += d_array[arraysize]
            del d_array[arraysize]

        r_array = [0 + n for n in xrange(arraysize)]
        random.shuffle(r_array)

        return d_array, r_array

def Packager(datafile, target):
	Pdftk_UncompressPDF(target)

	with open('uncomp.pdf', 'r+b') as pdf:
		src = pdf.read()

	os.remove('uncomp.pdf')
	array = re.findall('(/Subtype /Image|/Subtype /Type1C|/BitsPerSample)', src)

	if not array:
		print '[-] No entrypoints found. Aborting.'
		exit

	count = 0
	arraysize = len(array)
	d_array, r_array = ProcessContraband(datafile, arraysize)

	temp = ''
	if arraysize == 1:
		print '[+] Only one entrypoint located. Inserting Data...'
		temp += src.split(array[0])[0] + array[0]
		temp += (src.split(array[0])[1].split('endstream')[0] + KEY + '0_' + d_array[0] + 'endstream')
		temp += src.split(array[0])[1].split('endstream', 1)[1]
		WriteFile('enc-file.pdf', temp)
	else:
		print ' [+] Inserting DATA CHUNK 1'
		temp += src.split(array[0])[0] + array[0]
		temp += ((src.split(array[0])[1] + array[0]).split(array[1])[0]).split('endstream')[0] + KEY + str(r_array[0]) + '_' + d_array[r_array[0]] + '\nendstream'
		temp += src.split(array[0])[1].split(array[1])[0].split('endstream')[1] + array[1]

		for index in xrange(1, arraysize - 1):
			print ' [+] Inserting DATA CHUNK %d' % (index+1)
			count = len(temp.split(array[index])) - 1
			temp += src.split(array[index])[count].split(array[index+1])[0].split('endstream', 1)[0] + KEY + str(r_array[index]) + '_' + d_array[r_array[index]] + '\nendstream'
			temp += src.split(array[index])[count].split(array[index+1])[0].split('endstream', 1)[1] + array[index+1]

		print ' [+] Inserting DATA CHUNK %d' % arraysize
		temp += src.split(array[arraysize-1])[count+1].split('endstream')[0] + KEY + str(r_array[arraysize - 1]) + '_' + d_array[r_array[arraysize - 1]] + '\nendstream'
		temp += src.split(array[arraysize-1])[count+1].split('endstream', 1)[1]
		
		WriteFile('enc-file.pdf', temp)
	
	# TOO DAMN SLOW
	Pdftk_CompressPDF('enc-file.pdf')
	os.remove('enc-file.pdf')

def WriteFile(filename, data):
	with open(filename, 'wb') as outfile:
		outfile.write(data)

def ItsChristmas(target):
    print '[*] Retrieving Package.'
    with open(target, 'r+b') as pdf:
        src = pdf.read()

    REGEX1 = KEY + '(.*?)\nendstream'
    DataChunks = re.findall(REGEX1, src, re.DOTALL)
    DataChunks.sort()

    Data = ''
    for chunk in DataChunks:
        Data += chunk.split('_', 1)[1]
    
    with open('outfile', 'w+b') as outfile:
        outfile.write(Data)

def Pdftk_UncompressPDF(target): 
    proc = Popen(['pdftk.exe', target, 'output', 'uncomp.pdf'])
    print '\n[*] Uncompressing target PDF.\n'
    proc.wait()

def Pdftk_CompressPDF(target):
    proc = Popen(['pdftk.exe', target, 'output', 'compressed.pdf'])
    print '\n[*] Compressing target PDF. This may take a looong time.'
    proc.wait()

if __name__ == "__main__":
    if sys.argv[1] == 'hide':
        Packager(sys.argv[2], sys.argv[3])
    if sys.argv[1] == 'reveal':
        ItsChristmas(sys.argv[2])
