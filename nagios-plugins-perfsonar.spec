%define install_base /usr/lib/perfsonar
%define plugin_base %{_libdir}/nagios/plugins
%define psconfig_base /usr/lib/perfsonar/psconfig/checks/

%define relnum 0.0.a1

Name:			nagios-plugins-perfsonar
Version:		4.1
Release:		%{relnum}%{?dist}
Summary:		perfSONAR Nagios Plugins
License:		Distributable, see LICENSE
Group:			Development/Libraries
URL:			http://www.nagios.org/
Source0:		nagios-plugins-perfsonar-%{version}.%{relnum}.tar.gz
BuildRoot:		%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

%package
Requires:		perl
Requires:		perl(Carp)
Requires:		perl(Data::UUID)
Requires:		perl(Data::Validate::IP)
Requires:		perl(English)
Requires:		perl(Exporter)
Requires:		perl(FindBin)
Requires:		perl(Getopt::Long)
Requires:		perl(IO::File)
Requires:		perl(LWP::Simple)
Requires:		perl(LWP::UserAgent)
Requires:		perl(Log::Log4perl)
Requires:		perl(Nagios::Plugin)
Requires:		perl(Params::Validate)
Requires:		perl(Statistics::Descriptive)
Requires:		perl(Time::HiRes)
Requires:		perl(XML::LibXML)
Requires:		perl(Cache::Memcached)
Requires:		perl(Mouse)
Requires:		perl(JSON::XS)
Requires:		memcached
Requires:		chkconfig
Requires:		coreutils
Requires:		shadow-utils
Requires:		libperfsonar-perl
Requires:		libperfsonar-esmond-perl
Requires:		libperfsonar-sls-perl
Obsoletes:		perl-perfSONAR_PS-Nagios
Provides:		perl-perfSONAR_PS-Nagios

%description
The perfSONAR Nagios Plugins can be used with Nagios to monitor the various
perfSONAR services.

%package utils
Summary:		perfSONAR Nagios MaDDash Check Plug-ins
Group:			Applications/Communications
Requires:		nagios-plugins-perfsonar
Requires:		perfsonar-psconfig-maddash

%description psconfig
Check plug-in files for the pSConfig MaDDash agent

%pre
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%prep
%setup -q -n nagios-plugins-perfsonar-%{version}.%{relnum}

%build

%install
rm -rf %{buildroot}

make ROOTPATH=%{buildroot}/%{install_base} LIBPATH=%{install_base}/lib PLUGINPATH=%{buildroot}/%{plugin_base} install

install -D -m 0644 psconfig/* %{buildroot}/%{psconfig_base}/
rm -rf psconfig

%clean
rm -rf %{buildroot}

%post
mkdir -p /var/log/perfsonar/nagios
chown perfsonar:perfsonar /var/log/perfsonar/nagios

%files
%defattr(-,perfsonar,perfsonar,-)
%attr(0755,perfsonar,perfsonar) %{plugin_base}/*
%attr(0755,perfsonar,perfsonar) %{install_base}/lib/*

%files psconfig
%defattr(-,perfsonar,perfsonar,-)
%{psconfig_base}/*

%changelog
* Thu Feb 15 2018 andy@es.net 4.1-0.0.a1
- Added psconfig package

* Thu Jun 18 2014 andy@es.net 3.4-2
- Added support for new MA
- Added -4 and -6 options

* Fri Jan 11 2013 asides@es.net 3.3-1
- 3.3 beta release
