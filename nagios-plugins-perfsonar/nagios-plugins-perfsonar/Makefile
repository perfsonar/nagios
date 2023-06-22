PACKAGE=nagios-plugins-perfsonar
ROOTPATH=/usr/lib/perfsonar
LIBPATH=${ROOTPATH}/lib
PLUGINPATH=/usr/lib/nagios/plugins
PERFSONAR_AUTO_VERSION=5.0.4
PERFSONAR_AUTO_RELNUM=0.a1.0
VERSION=${PERFSONAR_AUTO_VERSION}
RELEASE=${PERFSONAR_AUTO_RELNUM}

default:
	@echo No need to build the package. Just run \"make install\"

dist:
	mkdir /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	tar ch -T MANIFEST | tar x -C /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	tar czf $(PACKAGE)-$(VERSION).$(RELEASE).tar.gz -C /tmp $(PACKAGE)-$(VERSION).$(RELEASE)
	rm -rf /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)


install:
	mkdir -p ${ROOTPATH}
	mkdir -p ${PLUGINPATH}
	tar ch --exclude=etc/* --exclude=*spec --exclude=dependencies --exclude=MANIFEST --exclude=LICENSE --exclude=Makefile -T MANIFEST | tar x -C ${ROOTPATH}
	sed -i 's:.Bin/\.\./lib:${LIBPATH}:g' ${ROOTPATH}/bin/*
	install ${ROOTPATH}/bin/* ${PLUGINPATH}
	rm -rf ${ROOTPATH}/bin
