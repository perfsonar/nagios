PACKAGE=nagios-plugins-perfsonar
ROOTPATH=/usr/lib/perfsonar
LIBPATH=${ROOTPATH}/lib
PLUGINPATH=/usr/lib/nagios/plugins
VERSION=4.1
RELEASE=0.0.a1

default:
	@echo No need to build the package. Just run \"make install\"

dist:
	mkdir /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	tar ch -T MANIFEST | tar x -C /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	cd /tmp/$(PACKAGE)-$(VERSION).$(RELEASE) && ln -s doc/LICENSE LICENSE
	cd /tmp/$(PACKAGE)-$(VERSION).$(RELEASE) && ln -s doc/INSTALL INSTALL
	cd /tmp/$(PACKAGE)-$(VERSION).$(RELEASE) && ln -s doc/README README
	tar czf $(PACKAGE)-$(VERSION).$(RELEASE).tar.gz -C /tmp $(PACKAGE)-$(VERSION).$(RELEASE)
	rm -rf /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)


install:
	mkdir -p ${ROOTPATH}
	mkdir -p ${PLUGINPATH}
	tar ch --exclude=etc/* --exclude=*spec --exclude=dependencies --exclude=MANIFEST --exclude=Makefile -T MANIFEST | tar x -C ${ROOTPATH}
	sed -i 's:.Bin/\.\./lib:${LIBPATH}:g' ${ROOTPATH}/bin/*
	install ${ROOTPATH}/bin/* ${PLUGINPATH}
	rm -rf ${ROOTPATH}/bin
