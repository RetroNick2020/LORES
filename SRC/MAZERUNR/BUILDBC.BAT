bcc -Z -I..\..\inc /DCGA_SNOW -emazebc.exe mazerunr.c ..\..\lib\loresbc.lib
bcc -S -I..\..\inc /DCGA_SNOW /DPROFILE /-emazepbc.exe mazerunr.c ..\..\lib\lrprofbc.lib
del *.obj
