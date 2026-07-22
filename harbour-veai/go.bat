@set oldpath=%path%
@set path=c:\bcc77\bin;%oldpath%
..\harbour\bin\win\bcc\hbmk2.exe veai.hbp -comp=bcc
veai.exe
@set path=%oldpath%