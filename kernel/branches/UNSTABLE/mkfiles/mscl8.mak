#
# MSCL8.MAK - kernel copiler options for MS CL8 = MS VC 1.52
#

TARGET=KMS

CC=$(BINPATH)\cl -batch -nologo -c
CL=$(BINPATH)\cl -batch -nologo

# used for building the library

CLIB=$(LIBPATH)\slibce.lib
MATH_EXTRACT=*aflmul *aFlshl *aFNauldi *aFulrem *aFulshr *aFuldiv *aFlrem *aFldiv *aFNaulsh
MATH_INSERT =+aflmul +aFlshl +aFNauldi +aFulrem +aFulshr +aFuldiv +aFlrem +aFldiv +aFNaulsh

#

!if $(XCPU) == 186
CPUOPT=-G1
!endif
!if $(XCPU) == 386
CPUOPT=-G3
!endif

ALLCFLAGS=@vc.cfg -I$(INCLUDEPATH) $(CPUOPT) $(ALLCFLAGS)
INITCFLAGS=-NTINIT_TEXT
CFLAGS    =-NTHMA_TEXT
INITPATCH=..\utils\patchobj _DATA=IDATA DATA=ID BSS=ID DGROUP=I_GROUP CONST=IC

CFLAGST=-I..\hdr -I$(INCLUDEPATH) /Fm /AT /Os /Zp1
CFLAGSC=-I..\hdr -I$(INCLUDEPATH) /Fm /AL /Os /Zp1
