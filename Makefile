PACKAGE=perfSONAR_PS-NagiosPlugins
ROOTPATH=/opt/perfsonar_ps/nagios
VERSION=3.1
RELEASE=11

default:
	@echo No need to build the package. Just run \"make install\"

rpminstall:
	mkdir -p ${ROOTPATH}
	tar ch --exclude=etc/* --exclude=*spec --exclude=MANIFEST --exclude=Makefile -T MANIFEST | tar x -C ${ROOTPATH}
	for i in `cat MANIFEST | grep ^etc`; do  mkdir -p `dirname $(ROOTPATH)/$${i}`; if [ -e $(ROOTPATH)/$${i} ]; then install -m 640 -c $${i} $(ROOTPATH)/$${i}.new; else install -m 640 -c $${i} $(ROOTPATH)/$${i}; fi; done

install:
	mkdir -p ${ROOTPATH}
	tar ch --exclude=etc/* --exclude=*spec --exclude=MANIFEST --exclude=Makefile -T MANIFEST | tar x -C ${ROOTPATH}
	for i in `cat MANIFEST | grep ^etc`; do  mkdir -p `dirname $(ROOTPATH)/$${i}`; if [ -e $(ROOTPATH)/$${i} ]; then install -m 640 -c $${i} $(ROOTPATH)/$${i}.new; else install -m 640 -c $${i} $(ROOTPATH)/$${i}; fi; done

