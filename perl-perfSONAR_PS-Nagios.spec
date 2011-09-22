%define _unpackaged_files_terminate_build      0
%define install_base /opt/perfsonar_ps/nagios

%define relnum 3
%define disttag pSPS

Name:           perl-perfSONAR_PS-Nagios
Version:        3.2.1
Release:        %{relnum}.%{disttag}
Summary:        perfSONAR_PS Nagios Plugins
License:        distributable, see LICENSE
Group:          Development/Libraries
Source0:        perfSONAR_PS-Nagios-%{version}.%{relnum}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch

Requires:               perl(Carp)
Requires:               perl(Data::UUID)
Requires:               perl(Data::Validate::IP)
Requires:               perl(English)
Requires:               perl(Exporter)
Requires:               perl(FindBin)
Requires:               perl(Getopt::Long)
Requires:               perl(IO::File)
Requires:               perl(LWP::Simple)
Requires:               perl(LWP::UserAgent)
Requires:               perl(Log::Log4perl)
Requires:               perl(Nagios::Plugin)
Requires:               perl(Params::Validate)
Requires:               perl(Statistics::Descriptive)
Requires:               perl(Time::HiRes)
Requires:               perl(XML::LibXML)
#Requires:       perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))
Requires:       perl
Requires:       coreutils
Requires:       shadow-utils
Requires:       chkconfig

%description
The perfSONAR_PS-Nagios Plugins can be used with Nagios to monitor the various perfSONAR services.

%pre
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%prep
%setup -q -n perfSONAR_PS-Nagios-%{version}.%{relnum}

%build

%install
rm -rf $RPM_BUILD_ROOT

make ROOTPATH=$RPM_BUILD_ROOT/%{install_base} rpminstall


%post
mkdir -p /var/log/perfsonar/nagios
chown perfsonar:perfsonar /var/log/perfsonar/nagios


%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,perfsonar,perfsonar,-)
%config %{install_base}/etc/*
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/*
%attr(0755,perfsonar,perfsonar) %{install_base}/lib/*
%{install_base}/doc/*
