# myool

The Python version of myool for both Windows and Linux. It is much faster since it doesn't hit disk a bunch of times. While functional(not really), it is not fully done yet. See pymyool.py for TODO list and usage.

Encrypt a file(archive) using AES-256 and hide it in any pdf document. \**requires pdftk for PDF compression*\*

### To hide a file:
```bash
./myool.sh hide [filetohide] [targetpdf]
```
### To reveal a file:
```bash
./myool.sh reveal [enc-targetpdf]
```
### Timed Example (with 297Mb zip archive)

![alt text](https://cloud.githubusercontent.com/assets/23404638/21740196/0ec15d9a-d467-11e6-8b00-c83d2b18ae45.png "largefile")

*note: pdftk may issue a warning when re-compressing*

### How it works
These object parameters: **"/Subtype /Type1C", "/Subtype /Image", or "/BitsPerSample"**, define streams which can hold raw binary data. *myool* looks for these parameters and their corresponding "endstream"'s which are recorded into an array of entrypoints. The entrypoints are shuffled randomly, then iterated through, copying chunks of data into each. Chunks are prepended with a secret key and an order number for easier extraction. The filesignature of the encrypted data is also overwritten so any attempt to look for it will fail unless the secret key is known and the chunks are recovered and re-ordered.
```
592 0 obj
<<
/Subtype /Image         <--- Safe entrypoint
/Name /Im1
/Type /XObject
/Filter /DCTDecode
/Width 700
/Height 901
/BitsPerComponent 8
/Length 82894           <--- Size of image in bytes. Our appended data size will be added after recompression
/ColorSpace /DeviceRGB
>>
stream
ÿØÿà^@^PJFIF^@^A^B^A^@È^@È^@^@ÿá^S_Exif^@^@MM^@*^@^@^@^H^@^G^A^R^@^C^@^@^@^A^@^A^@^@^A^Z^@^E^@^@^@
^A^@^@^@b^A^[^@^E^@^@^@^A^@^@^@j^A(^@^C^@^@^@^A^@^B^@^@^A1^@^B^@^@^@^T^@^@^@r^A2^@^B^@^@^@^T^@^@^@
<86><87>i^@^D^@^@^@^A^@^@^@<9c>^@^@^@È^@^@^@È^@^@^@^A^@^@^@È^@^@^@^AAdobe Photoshop 7.0^@2010:06:0       
413:27:46^@^@^@^@^C ^A^@^C^@^@^@^Aÿÿ^@^@ ^B^@^D^@^@^@^A^@^@^B¼ ^C^@^D^@^@^@^A^@^@^C<85>^@^@^@^@^@
^@^@^F^A^C^@^C^@^@^@^A^@^F^@^@^A^Z^@^E^@^@^@^A^@^@^A^V^A^[^@^E^@^@^@^A^@^@^A^^^A(^@^C^@^@^@^A^@^B^
@^@^B^A^@^D^@^@^@^A^@^@^A&^B^B^@^D^@^@^@^A^@^@^R1^@^@^@^@^@^@^@H^@^@^@^A^@^@^@H^@^@^@^AÿØÿà^@^PJFI
F^@^A^B^A^@H^@H^@^@ÿí^@^LAdobe_CM^@^Bÿî.......raw binary data
6d796f6f6c7                     <--- Identifier = "6d796f6f6c" + ordernumber(7)
encrypted data chunk goes here  <--- Appended data
endstream
```

When it comes time to recompress the $targetpdf to $enc-targetpdf, *pdftk* will correct the objects and the XREF table to accomodate the increase in size. The result of this injection should not affect the quality of images, fonts, pages, loading times, etc. But that isn't guaranteed! Results may vary!

If no parameters are found, the $targetpdf will still contain some stream in it that may be used for injection. Most of the time it is a text stream *see below*. However, the stream may not be meant to hold raw binary data. 
```
5 0 obj
<<
/Length 98                <--- Gets fixed after recompression
>>
stream
q 0.1 0 0 0.1 0 0 cm
0 g
q
10 0 0 10 0 0 cm BT
/R7 40 Tf
1 0 0 1 150 550 Tm
(Hello World)Tj           <--- Prints "Hello World" on the page
ET
Q
Q
6d796f6f6c                <--- Identifier
encrypted data goes here  <--- Appended data
endstream 
```
If thats the case, then theres a good chance you will run into warnings regarding the format or data on the page where the data was injected into. The page could raise an error and or not display anything at all. And lastly, depending on the size of the encrypted data, the resultant pdf may spend some time loading when you open it, before displaying the pages (regardless of which reader you use).
