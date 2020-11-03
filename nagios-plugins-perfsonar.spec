%define install_base /usr/lib/perfsonar
%define plugin_base %{_libdir}/nagios/plugins

%define perfsonar_auto_version 4.4.0
%define perfsonar_auto_relnum 0.a1.0

Name:			nagios-plugins-perfsonar
Version:		%{perfsonar_auto_version}
Release:		%{perfsonar_auto_relnum}%{?dist}
Summary:		perfSONAR Nagios Plugins
License:		ASL 2.0
Group:			Development/Libraries
URL:			http://www.nagios.org/
Source0:		nagios-plugins-perfsonar-%{version}.%{perfsonar_auto_relnum}.tar.gz
BuildRoot:		%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
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
Requires:		python
Requires:		python-pyjq
Requires:		python-argparse
Requires:		python-pscheduler
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

%pre
/usr/sbin/groupadd -r perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%prep
%setup -q -n nagios-plugins-perfsonar-%{version}.%{perfsonar_auto_relnum}

%build

%install
rm -rf %{buildroot}

make ROOTPATH=%{buildroot}/%{install_base} LIBPATH=%{install_base}/lib PLUGINPATH=%{buildroot}/%{plugin_base} install

%clean
rm -rf %{buildroot}

%post
mkdir -p /var/log/perfsonar/nagios
chown perfsonar:perfsonar /var/log/perfsonar/nagios

%files
%defattr(-,perfsonar,perfsonar,-)
%license LICENSE
%attr(0755,perfsonar,perfsonar) %{plugin_base}/*
%attr(0755,perfsonar,perfsonar) %{install_base}/lib/*

%changelog
* Thu Jun 18 2014 andy@es.net 3.4-2
- Added support for new MA
- Added -4 and -6 options

* Fri Jan 11 2013 asides@es.net 3.3-1
- 3.3 beta release
