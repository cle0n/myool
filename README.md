# myool

Encrypt a file using AES-256 and hide it in any pdf document.

###To hide a file:
```bash
./myool.sh hide [filetohide] [targetpdf]
```
###To reveal a file:
```bash
./myool.sh reveal [enc-targetpdf]
```
###How it works
These object parameters: **"/Subtype /Type1C", "/Subtype /Image", or "/BitsPerSample"**, have streams which can hold raw binary data and are considered safe. The first parameter found in the $targetpdf will be used for the injection, and henceforth the last occurence of that parameter will be the entrypoint. The encrypted data will be appended to the data already present in the stream along with a prepended identifier "6d796f6f6c"(myool). The result of this injection should not affect the quality of images, fonts, pages, loading times, etc. But that isn't guaranteed! Results may vary!

![alt text](https://cloud.githubusercontent.com/assets/23404638/21740196/0ec15d9a-d467-11e6-8b00-c83d2b18ae45.png "largefile")

*note: pdftk may issue a warning when re-compressing*

If no parameters are found, the $targetpdf will still contain a stream in it that may be used for injection. However, the stream may not be meant for raw binary data. If thats the case, then theres a good chance you will run into warnings regarding the format or data on the page where the data was injected into. The page could raise an error and or not display anything at all. And lastly, depending on the size of the encrypted data, the resultant pdf may spend some time loading when you open it, before displaying the pages (regardless of which reader you use).

###**FUTURE:**

1. SPLIT-SPREAD-SCRAMBLE the data throughout the $targetpdf, if multiple parameters are found.
