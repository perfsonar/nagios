				PERFSONAR-NAGIOS PLUGINS

INTRODUCTION
The set of plugins are used to check the health of the various perfSONAR services
that have been deployed on various hosts and have been collecting data for quite sometime.
Currently there are 9 plugins available. They are:
	01. check_gls.pl
	02. check_hls.pl
	03. check_ls.pl
	04. check_pinger.pl
	05. check_topology.pl
	06. check_snmp.pl
	07. check_throughput.pl
	08. check_owdelay.pl
	09. check_traceroute.pl
	10. check_perfSONAR.pl
	11. check_ps_version.pl

INSTALLATION REQUIREMENTS
The plugins require Perl(>5.0) and Nagios. Additionally, please ensure that
the following perl modules have been installed. 
	(+)Data::UUID
	(+)Data::Validate::IP
	(+)LWP::Simple
	(+)LWP::UserAgent
	(+)Nagios::Plugin
	(+)Params::Validate
	(+)Statistics::Descriptive
	(+)XML::LibXML
	(+)Log::Log4Perl
The perl modules can be installed via CPAN or using the RPM files. If using CPAN, then
use the --nodeps option while installing the Nagios-Plugins.

INSTALLATION
Use RPM to install the plugins. You may choose to use the --nodeps option if you 
have installed all the required plugins via CPAN. Otherwise, install all the required 
plugins using the respective rpms and then install the Nagios-Plugins

PLUGIN DESCRIPTION	

1. CHECK_GLS.PL
This plugin searches the contents of the Global Lookup Service(GLS) and returns the number of HLSes found based on the search criteria specified. When none of the search options are specified, it returns all the HLSes found in the GLS.

Input options:
-u|--url   -   (Optional)  url of the GLS service that has to be searched. If more than one has to be specified, use 'h' option to specify the URL of the file that contains the list of GLS to contact. You can also use the default perfSONAR hints file. 
		
-h|--hintsURL -  (Optional) Host the file containing a list of GLS URLs and specify the URL here. The plugin will search the GLSes in the list one after the other. When an appropriate response is received, the search is halted and the plugin returns the results.

-f|--hlsurlfile -  (Optional) Specify the file (with complete path on the filesystem) that has the list of HLSes that need to be found in the GLS. If left blank, the plugin returns everything.

-t|--typeofservice - (Optional). The type of service to be searched for. If this is specified, only HLS with the "type of service" registered in the GLS is returned.
	
-k|--keyword -    (Optional) Any keyword that has to be included in the search criteria.

-w|--warning -     (Required) If the number of HLSes returned falls below or above the threshold, the plugin returns WARNING state. Please refer to Nagios documentation for details about setting this value.

-c|--critical -    (Required) If the number of HLSes returned falls below or above the threshold, the plugin returns CRITICAL state. Please refer to Nagios documentation for details about setting this value.

-v|--verbose -     (Optional) Runs in verbose mode. Useful for debugging or running as a perl module

-i|--initialConfig - (Optional) Specify a config file that contains the mapping between the keyword used for a service and the full namespace of the service. If this is not specified, the full URLs have to be used instead of the short names.

--timeout - (Optional) Seconds before plugin times out (default: 60)


Output:
Nagios state: OK, WARNING, CRITICAL or UNKNOWN along with the number of HLSes found.


Examples:
#  Examples below throw a WARNING if the number of registered HLSes goes below 10 and shows CRITICAL status if the number goes below 5

	* Return count of all the registered HLS services
	  check_gls.pl -c 5: -w 10:

	* Count number of HLSes registered in the GLS that belong to ESnet
	  check_gls.pl -c 5: -w 10: -k ESnet

	* Count number of bwctl services registered
	(With a config file that provides mapping of services to their keywords. More details about config file is given in the next section)
	  check_gls.pl -c 5: -w 10: -t bwctl -i /path/to/file/
	
	(Without a config file)
	 check_gls.pl -c 5: -w 10: -t http://ggf.org/ns/nmwg/tools/bwctl/1.0

	* Count number of bwctl services that belong to ESnet
	(With a config file that provides mapping of services to their keywords. More details about config file is given in the next section)
	  check_gls.pl -c 5: -w 10: -t bwctl -i /home/nagios/servicemapping.txt -k ESnet
	
	(Without a config file)
	 check_gls.pl -c 5: -w 10: -t http://ggf.org/ns/nmwg/tools/bwctl/1.0 -k ESnet

	* Check if the HLSes specified in the file are found in ps1.es.net GLS
	check_gls.pl -c 5: -w 10: -s http://ps1.es.net:9990/perfSONAR_PS/services/gLS  -f /path/to/file/

	* Check if the HLSes specified in the file are found in any GLS
	check_gls.pl -c 5: -w 10:  -f /path/to/file/
	



2. CHECK_HLS.PL

This plugin searches the contents of the given HLSes and returns the number of services registered in the
HLS(es) based on the search criteria. If nothing is specified, it returns everything. The search can be based on
type of service or a keyword.

Optionally it can be used to check for a service in the GLS and see if the service is registered in the HLS that it returns.

Input options:
-u|--url  - 	(Optional) URL of the HLS to contact. If more than one HLS has to be specified, use -f option to include a file 
		containing the list of HLSes. Either -u or -f has to be specified, else an error will be thrown.

-f|--hlsurlfile - 	(Optional) File containing the list of HLSes. Either -u or -f has to be specified, else an error will be thrown.

-t|--type - 	(Optional) Type of service. If more than one, specify them separated by comma. 'all' or specify nothing - for all services

-g|--glsMode - specify gls hints URL that has to be searched for.

-h|--hintsURL - If more than one GLS URL has to be specified, then use this option. Include all the URLs in a file and provide the URL of file. Or, you can use the default perfSONAR URL.

-k|--keyword -    (Optional) Any keyword that has to be included in the search criteria.

-v|--verbose -     (Optional) Runs in verbose mode. Useful for debugging or running as a perl module

-i|--initialConfig - (Optional) Specify a config file that contains the mapping between the keyword used for a service and the full namespace of the service. If this is not specified, the full URLs have to be used instead of the short names.

-w|--warning -     (Required) If the number of services returned falls below or above the threshold, the plugin returns WARNING state. Please refer to Nagios documentation for details about setting this value.

-c|--critical -    (Required) If the number of services returned falls below or above the threshold, the plugin returns CRITICAL state. Please refer to Nagios documentation for details about setting this value.

--timeout - (Optional) Seconds before plugin times out (default: 60)

Output:
Nagios state: OK, WARNING, CRITICAL or UNKNOWN along with the number of services found.

Examples:
#  Examples below throw a WARNING if the number of registered services(MAs) in the HLS goes below 10 and shows CRITICAL status if the number goes below 5

	* Return count of all the services registered in the HLS
	  check_hls.pl -c 5: -w 10:

	* Count the number of bwctl MAs registered in the HLS
	  check_hls.pl -c 5: -w 10: -t bwctl -i /path/to/file
				OR
	  check_hls.pl -c 5: -w 10: -t http://ggf.org/ns/nmwg/tools/bwctl/1.0

	* Check if the services registered in GLS exist in the HLS or not
	  Single GLS - 
	  check_hls.pl -c 5: -w 10: -g http://ps1.es.net:9990/perfSONAR_PS/services/gLS -t bwctl -i /path/to/file

	  Multiple GLS
	  check_hls.pl -c 5: -w 10: -g http://ps1.es.net:9990/perfSONAR_PS/services/gLS -t bwctl -i /path/to/file

3. CHECK_LS.PL

Verifies that the lookup service is running. Unlike check_gls and check_hls it does not alert based on the number of services registered. This is intended to be a simple service health check.

Input options:
-?, --usage
   Print usage information
-h, --help
   Print detailed help screen
-V, --version
   Print version information
--extra-opts=[section][@file]
   Read options from an ini file. See http://nagiosplugins.org/extra-opts
   for usage and examples.
-u, --url=STRING
   URL of the Lookup Service to contact.
-t, --timeout=INTEGER
   Seconds before plugin times out (default: 15)
-v, --verbose
   Show details for command-line debugging (can repeat up to 3 times)

Output:
Nagios state: OK, WARNING, CRITICAL or UNKNOWN.

Examples:
    * Check if the LS is running at the given URL
    ./bin/check_ls.pl -u http://ps2.es.net:8095/perfSONAR_PS/services/hLS
	
4. CHECK_PINGER.PL

This plugin queries PINGER MA to check if the RTT between the given source and destination for the given time interval is within the specified range.

Input options:

-u|--url - 	(Required) URL of the Pinger MA to contact. Only one URL can be specified

-s|--source - 	(Required) Source address or hostname of the test. The source format should be same as the one with which it was registered in the pingerMA.

-d|--destination - (Required) Destination address or hostname of the test. The destination format should be same as the one with which it was registered in the pingerMA.

-r|--range - 	(Required) Time range (in minutes) in the past to look at data. i.e. 60 means look at last 60 minutes of data.

-k|--rttType - (Optional) RTT type to be analyzed - min,max,mean. Pinger results have all the three available. If nothing is specified, minRtt is used.

-f|--function - (Optional) statistical function to be used to analyze the returned results. min, max and mean are currently available. Default is min.

-w|--warning -  (Required) If the RTT value returned falls below or above the threshold, the plugin returns WARNING state. Please refer to Nagios documentation for details about setting this value.

-c|--critical -  (Required) If the RTT value returned falls below or above the threshold, the plugin returns CRITICAL state. Please refer to Nagios documentation for details about setting this value.

-v|--verbose -     (Optional) Runs in verbose mode. Useful for debugging or running as a perl module

-t|--timeout - (Optional) Seconds before plugin times out (default: 60)

Output:
Nagios state: OK, WARNING, CRITICAL or UNKNOWN along with the RTT value.


Examples:

	* Check if the maximum RTT between atla-owamp.es.net and anl-owamp.es.net during the last hour crossed 20s
	  check_pinger.pl -u http://atla-owamp.es.net:8075/perfSONAR_PS/services/pinger/ma -w @17:20 -c @20: -r 60 -s  atla-owamp.es.net  -d anl-owamp.es.net -k maxRtt -f max

	* Check the average RTT between atla-owamp.es.net and anl-owamp.es.net during the last 3 hours
	  check_pinger.pl -u http://atla-owamp.es.net:8075/perfSONAR_PS/services/pinger/ma -w @17:20 -c @20: -r 1800 -s  atla-owamp.es.net  -d anl-owamp.es.net -k meanRtt -f average

5. CHECK_TOPOLOGY.PL

This plugin queries the given topology URL to check if the topology has the specified number of nodes in its topology map.

Input Options:
-u|--url - Topology URL to contact Ð Only one MA URL can be specified

-d|--domainName - (Required) domain name used in the topology (For eg: es.net, ps.es.net)

-n|--namespace - (Required) Namespace being used to store the topology details

-w|--warning -  (Required) If the number of nodes in the topology falls below or above the threshold, the plugin returns WARNING state.  Please refer to Nagios documentation for details about setting this value.

-c|--critical -  (Required) If the number of nodes falls below or above the threshold, the plugin returns CRITICAL state. Please refer to Nagios documentation for details about setting this value.

-v|--verbose -   (Optional) Runs in verbose mode. Useful for debugging or running as a perl module

-i|--initialConfig - (Optional) Specify a config file that contains the mapping between the keyword used for a service and the full namespace of the service. If this is not specified, the full URLs have to be used instead of the short names.

-t|--timeout - (Optional) Seconds before plugin times out (default: 60)

Output:
Nagios state: OK, WARNING, CRITICAL or UNKNOWN along with the number of nodes in the topology.


Examples:

	* Check if the total number of nodes in es.net domain registered with ps3.es.net topology MA is above 70 nodes
	check_topology.pl -w 70: -c 50: -u http://ps3.es.net:8012/perfSONAR_PS/services/topology -d es.net -n CtrlPlane -i /path/to/file
								OR
	check_topology.pl -w 70: -c 50: -u http://ps3.es.net:8012/perfSONAR_PS/services/topology -d es.net -n http://ogf.org/schema/network/topology/ctrlPlane/20080828/

6. CHECK_SNMP.PL
This plugin queries the given SNMP MA to check if the average utilization of the test with given parameters is within the specified range.

Input options:
-u|--url -  (Required) URL of the SNMP MA to contact	

-d|--direction - (Required) traffic direction. Eg: in(inbound) or out(outbound). Specify "in" or "out"

-i|--interface - (Required) interface address of the required measurement statistics.

-t|--timeInterval - (Required) time interval in minutes for the measurement statistics

-w|--warning -  (Required) If the average utilization in the topology falls below or above the threshold, the plugin returns WARNING state. Please refer to Nagios documentation for details about setting this value.

-c|--critical -  (Required) If the average utilization falls below or above the threshold, the plugin returns CRITICAL state. Please refer to Nagios documentation for details about setting this value.

-v|--verbose -   (Optional) Runs in verbose mode. Useful for debugging or running as a perl module

--timeout - (Optional) Seconds before plugin times out (default: 60)

Output:
Nagios state: OK, WARNING, CRITICAL or UNKNOWN along with the average utilization and traffic direction in the topology.


Examples:

	* Check if the average utilization on the inbound traffic on interface 206.196.182.4  is below 7Gbps during the last 1 hour
	  check_snmp.pl-u http://desk172.internet2.edu:9990/perfSONAR_PS/services/SNMPMA -d in -i 206.196.182.4 -t 60 -c ~:7e+9 -w ~:5e+9

	* Check if the average utilization on the outbound traffic on interface 206.196.182.4  is below 7Gbps during the last 1 hour
	  check_snmp.pl-u http://desk172.internet2.edu:9990/perfSONAR_PS/services/SNMPMA -d out -i 206.196.182.4 -t 60 -c ~:7e+9 -w ~:5e+9

7. CHECK_THROUGHPUT

This plugin queries the given MA to check if a particular src-dst pairÕs throughput is within the specified range.


Input options:
-u|--url - (Required) URL of the MA to contact

-s|--source - (Optional) Source address or hostname of the test. If left blank then plugin will match any source.

-d|--destination - (Optional) Destination address or hostname of the test. If left blank then plugin will match any destination.

-r|--range - (Required)	Time range (in seconds) in the past to look at data. i.e. 60 means look at last 60 seconds of data

-p|protocol - (Optional) The protocol used by the test to check (e.g. TCP or UDP)

-b|--bidirectional - (Optional) Indicates that test should be checked in each direction.

-w|--warning - (Required) If the throughput goes below or above this value, WARNING status is shown in Nagios . Please refer to Nagios documentation for details about setting this value.

-c|--critical - (Required) If the throughput goes below or above this value, CRITICAL status is shown in Nagios. Please refer to Nagios documentation for details about setting this value.

-t|--timeout - (Optional) Seconds before plugin times out (default: 60)

Output options:
Nagios state: OK, WARNING, CRITICAL or UNKNOWN along with avg throughout


Examples:
#  Examples below alert WARNING when average throughput falls below 1Gbps and alert CRITICAL when bandwidth falls below 500Mbps:

    * Check unidirectional results from bnl-pt1.es.net(198.124.238.38) to sunn-pt1.es.net(198.129.254.58).

          check_throughput.pl -u http://bnl-pt1.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w 1: -c .5: -s 198.124.238.38 -d 198.129.254.58 

    * Check bidirectional results from bnl-pt1.es.net(198.124.238.38) to sunn-pt1.es.net(198.129.254.58). Alert if there is no data in either of the directions (i.e. the test is not bidirectional).

          check_throughput.pl -u http://bnl-pt1.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w 1: -c .5: -s 198.124.238.38 -d 198.129.254.58 -b 

    * Check throughput for all outgoing tests from bnl-pt1.es.net(198.124.238.38).

          check_throughput.pl -u http://bnl-pt1.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w 1: -c .5: -s 198.124.238.38 

    * Check throughput for all incoming tests to bnl-pt1.es.net(198.124.238.38).

          check_throughput.pl -u http://bnl-pt1.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w 1: -c .5: -d 198.124.238.38 

    * Check throughput for all outgoing AND incoming tests from/to bnl-pt1.es.net(198.124.238.38). Also alert if any of the matched tests do not have data in both directions. (NOTE: YOU ONLY NEED TO USE ONE OF THE COMMANDS BELOW. BOTH THE COMMANDS BELOW ARE EQUIVALENT AND RESULT IN THE EXACT SAME CHECK)

          check_throughput.pl -u http://bnl-pt1.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w 1: -c .5: -s 198.124.238.38 -b OR check_throughput.pl -u http://bnl-pt1.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w 1: -c .5: -d 198.124.238.38 -b 

    * Check throughput for all tests in the given MA.

          check_throughput.pl -u http://bnl-pt1.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w 1: -c .5: 

    * Check throughput for all tests in the given MA. Alert if any of the tests do not have data in both directions

          check_throughput.pl -u http://bnl-pt1.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w 1: -c .5: -b 
   
   * Check throughput for all UDP tests in the given MA. Alert if any of the tests do not have data in both directions

          check_throughput.pl -u http://bnl-pt1.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -p UDP -w 1: -c .5: -b 



8. CHECK_OWAMP.PL

This plugin queries OWAMP MA to check if the test between given source and destination is within the specified range.

Input options:
-u|--url - (Required) URL of the MA to contact

-s|--source - (Optional) Source address or hostname of the test. If left blank then plugin will match any source.

-d|--destination - (Optional) Destination address or hostname of the test. If left blank then plugin will match any destination.

-r|--range - (Required) Time range (in seconds) in the past to look at data. i.e. 60 means look at last 60 seconds of data

-b|--bidirectional - (Optional) Indicates that test should be checked in each direction.

-l|--loss - (Optional) Specify this to look at packet loss instead of delay

-w|--warning - (Required) threshold of delay in milliseconds that leads to WARNING status. In loss mode this is average packets lost and has to be an integer

-c|--critical - (Required) threshold of delay in milliseconds that leads to CRITICAL status. In loss mode this is average packets lost and has to be an integer

-t|--timeout - (Optional) Seconds before plugin times out (default: 60)

Output options:
Nagios state: OK, WARNING, CRITICAL or UNKNOWN along with loss or delay


Examples:
# Check unidirectional results from bnl-owamp.es.net(198.124.238.49) to sunn-owamp.es.net(198.129.254.78).

    * Average Minumum Delay (Warning if above 45ms, critical if above 60ms):

          check_owdelay.pl -u http://bnl-owamp.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w :45 -c 60: -s 198.124.238.49 -d 198.129.254.78 

    * Average Loss (WARNING if loss > 0, CRITICAL if > 1 packet lost per minute):

          check_owdelay.pl -u http://bnl-owamp.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w 0 -c :1 -s 198.124.238.49 -d 198.129.254.78 -l 

# Check bidirectional results from bnl-owamp.es.net(198.124.238.49) to sunn-owamp.es.net(198.129.254.78). Alert if there is no data in either of the directions (i.e. the test is not bidirectional).

    * Average Minumum Delay (Warning if above 45ms, critical if above 60ms):

          check_owdelay.pl -u http://bnl-owamp.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w :45 -c 60: -s 198.124.238.49 -d 198.129.254.78 -b 

    * Average Loss (WARNING if loss > 0, CRITICAL if > 1 packet lost per minute):

          check_owdelay.pl -u http://bnl-owamp.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w 0 -c :1 -s 198.124.238.49 -d 198.129.254.78 -l -b 

# Check results for all outgoing tests from bnl-owamp.es.net(198.124.238.49).

    * Average Minumum Delay (Warning if above 45ms, critical if above 60ms):

          check_owdelay.pl -u http://bnl-owamp.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w :45 -c 60: -s 198.124.238.49 

    * Average Loss (WARNING if loss > 0, CRITICAL if > 1 packet lost per minute):

          check_owdelay.pl -u http://bnl-owamp.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w 0 -c :1 -s 198.124.238.49 -l 

# Check results for all incoming tests to bnl-owamp.es.net(198.124.238.49).

    * Average Minumum Delay (Warning if above 45ms, critical if above 60ms):

          check_owdelay.pl -u http://bnl-owamp.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w :45 -c 60: -d 198.124.238.49 

    * Average Loss (WARNING if loss > 0, CRITICAL if > 1 packet lost per minute):

          check_owdelay.pl -u http://bnl-owamp.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w 0 -c :1 -d 198.124.238.49 -l 

# Check results for all outgoing AND incoming tests from/to bnl-owamp.es.net(198.124.238.49). Also alert if any of the matched tests do not have data in both directions.

    * Average Minumum Delay (Warning if above 45ms, critical if above 60ms):

          check_owdelay.pl -u http://bnl-owamp.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w :45 -c 60: -s 198.124.238.49 -b OR check_owdelay.pl -u http://bnl-owamp.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w :45 -c 60: -d 198.124.238.49 -b 

    * Average Loss (WARNING if loss > 0, CRITICAL if > 1 packet lost per minute):

          check_owdelay.pl -u http://bnl-owamp.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w 0 -c :1 -s 198.124.238.49 -l -b OR check_owdelay.pl -u http://bnl-owamp.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w 0 -c :1 -d 198.124.238.49 -l -b 

# Check results for all tests in the given MA.

    * Average Minumum Delay (Warning if above 45ms, critical if above 60ms):

          check_owdelay.pl -u http://bnl-owamp.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w :45 -c 60: 

    * Average Loss (WARNING if loss > 0, CRITICAL if > 1 packet lost per minute):

          check_owdelay.pl -u http://bnl-owamp.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w 0 -c :1 -l 

# Check results for all tests in the given MA. Alert if any of the tests do not have data in both directions

    * Average Minumum Delay (Warning if above 45ms, critical if above 60ms):

          check_owdelay.pl -u http://bnl-owamp.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w :45 -c 60: -b 

    * Average Loss (WARNING if loss > 0, CRITICAL if > 1 packet lost per minute):

          check_owdelay.pl -u http://bnl-owamp.es.net:8085/perfSONAR_PS/services/pSB -r 3600 -w 0 -c :1 -l -b 


9. CHECK_TRACEROUTE.PL

This plugin queries a traceroute MA and alerts on the number of unique traceroute results seen over the 
specified time range. This can be used to determine if a path between two endpoints is changing. If
no source and destination is provided then it will return the highest number of unique paths it counts between
two endpoints. As an example, if an MA contains a traceoute between point A and B that has seen the same 
results everytime (so 1 unique result) and another between point A and C that has seen 3 unique results, 
then the plug-in will alert based on the value 3.

Input options:
-u|--url - (Required) URL of the MA service to contact

-s|--source - (Optional) Source of the test to check. If no destination is specified then the plug-in will look at all results where the provided value is the source.

-d|--destination - (Optional) Destination of the test to check

-r|--range - (Required) Time range (in seconds) in the past to look at data. i.e. 60 means look at last 60 seconds of data.

-w|--warning -(Required) threshold of path count that leads to WARNING status

-c|--critical -(Required) threshold of path count that leads to CRITICAL status

-t|--timeout - (Optional) Seconds before plugin times out (default: 60)

Output options:
Nagios state: OK, WARNING, CRITICAL or UNKNOWN along with stats about the number of paths observed. 
When multiple enpdoint pairs are analyzed the stats will be report the MIN, MAX, AVERAGE, and STANDARD
DEVIATION of the number of paths observed. It also reports stats on the times each test observed has run
in teh given time range.

Examples:
# Warn if there is two paths observed and critical if > 2 between fnal-pt1.es.net and anl-pt1.es.net in the last hour

          check_traceroute.pl -u http://fnal-pt1.es.net:8085/perfSONAR_PS/services/tracerouteMA -r 3600 -s fnal-pt1.es.net -d anl-pt1.es.net -w 1 -c :2

# Warn if there is two paths observed and critical if > 2 on any test with source fnal-pt1.es.net
 
          check_traceroute.pl -u http://fnal-pt1.es.net:8085/perfSONAR_PS/services/tracerouteMA -r 3600 -s fnal-pt1.es.net -w 1 -c :2

# Warn if there is two paths observed and critical if > 2 on any test with destination anl-pt1.es.net
 
          check_traceroute.pl -u http://fnal-pt1.es.net:8085/perfSONAR_PS/services/tracerouteMA -r 3600 -d anl-pt1.es.net -w 1 -c :2

# Warn if there is two paths observed and critical if > 2 on any test in the MA
 
          check_traceroute.pl -u http://fnal-pt1.es.net:8085/perfSONAR_PS/services/tracerouteMA -r 3600 -w 1 -c :2
          
          
10. CHECK_PERFSONAR.PL <URL> <FILE>

Sends a request to the perfSONAR service specified by the given URL and throws critical if it does not get a response. It can send an echo request, a SetupDataRequest, or a custom request (by specifying an XML file).

<url>   - (Optional) The URL of the perfSONAR service to contact

<file>  - (Optional) a file with the custom XML request to sent to the server 

--template - (Optional) if nofile specified, indicates the typ of query. Set to '2' for an echo request.

--debug - (Optional) runs plug-in in degub mode. Should not be used in production.          

--server - (Optional) if no <url> given, the host portion of the URL for the service to contact

--port   - (Optional) if no <url> given, the port portion of the URL for the service to contact 
     
--endpoint - (Optional) if no <url> given, the endpoint portion of the URL for the service to contact

--filter - (Optional) an XPath expression to filter results returned

--help -  (Optional) displays help message      

--interfaceIP - (Optional) if not an echo request or custom request, then the IP of the interface to query

--hostname - (Optional) if not an echo request or custom request, then the hostname of the interface to query  
   
--interfaceName - (Optional) if not an echo request or custom request, then the ifname of the interface to query

Output options:
Nagios state: OK or critical if response not returned

11. CHECK_PS_VERSION.PL

NAGIOS plugin to check the version of a toolkit host. Looks in the hLS for the 
pS-NPToolkit-${version} keyword. Checks the ping service for now since all hosts have that.

Input options:
-u|--url - (Required) URL of the lookup service (hLS) to contact.

-v, --version - (Required) Version required for check to pass

-c|--critical - (Optional) This is just a flag and does not take any options. Return CRITICAL if version does not match. Default is WARNING.

-t|--timeout - (Optional) Seconds before plugin times out (default: 60)

 --debug - (Optional) allow verbose mode for debugging
   
Output options:
Nagios state: OK, WARNING, CRITICAL or UNKNOWN. The output also contains the version it does find for every
   state except UNKNOWN. 

Examples:
# Warn if the toolkit hosting the specified LS is not running version 3.2.1

          check_ps_version.pl -u http://ps-bw.es.net:9995/perfSONAR_PS/services/hLS -v 3.2.1

# Throw a CRITICAL alarm if the toolkit hosting the specified LS is not running version 3.2.1

          check_ps_version.pl -u http://ps-bw.es.net:9995/perfSONAR_PS/services/hLS -v 3.2.1 -c

         
         
CONFIG FILES
InitialConfig File:
Some plugins require a config file that provides the mapping between the abbreviation used and the full namespace of the service. The config file typically looks as follows:

pinger => http://ggf.org/ns/nmwg/tools/pinger/2.0
snmp => http://ggf.org/ns/nmwg/tools/snmp/2.0
npad => http://ggf.org/ns/nmwg/tools/npad/1.0
ndt => http://ggf.org/ns/nmwg/tools/ndt/1.0


HLS URL file:
A file containing list of HLS or GLS URLs will look like this:

http://ps1.es.net:9990/perfSONAR_PS/services/gLS
http://ps3.es.net:9990/perfSONAR_PS/services/gLS
http://ps5.es.net:9990/perfSONAR_PS/services/gLS


FREQUESTLY ASKED QUESTIONS (FAQs)

1. Where can I learn more about nagios configuration file formats?

Please see the site: http://nagios.sourceforge.net/docs/nagioscore/3/en/config.html. Your configuration
files will depend on your format and needs of your network. Describing all teh ways Nagios allow you to 
configure the plug-ins is beyond the scope of this document. 

--------

2. Where can I learn more about the format of the -w and -c options?

See http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT for a full syntax.

--------

3. How do I configure the plug-ins to use a HTTP proxy?

Many of the nagios plug-ins commucicate with the perfSONAR service being checked via HTTP. If
you are behind an HTTP PROXY you will need to configure the plug-ins to use it. You can do 
this by setting the HTTP_PROXY environment variable on your system.

--------