#!/usr/bin/perl
#
# Monitor hardware health of Cisco UCS servers
# Tested on C220 servers
#
# theunixguys.com
#
#################################
#
# status lines for nagios
#
# 0 = OK
# 1 = Warning
# 2 = Critical
# 3 = Unknown
#
#################################
#
# requires ipmitool package
# requires nrpe user have sudo access for ipmitool and dmidecode
#
#################################


my $status = 0;
my $count  = 0;
my $IPMITOOL = '/usr/bin/ipmitool';
my $DMIDECODE = '/usr/sbin/dmidecode';
my $CHECKONLY;
my $DMITYPE;
my $DMESG = '/var/log/dmesg';
my $ERRCOUNT = 0;
my $ERRMSG;

my $RAIDCONT;
my $VDISK;
my $PDISK;
my $WRITEPOL;
my $RAIDBATT;
my $FANS;
my $PSU;
my $TEMP;
my $VOLTAGE;

if ($ARGV[0]) {
   $CHECKONLY = $ARGV[0];
} else {
   $CHECKONLY = 'ALL';
}

$DMITYPE = get_vendor();

################################

if ($DMITYPE =~ m/Cisco/i) {

   $PLATFORM = "sudo $IPMITOOL sdr type \'Platform Alert\' | cut -d \'|\' -f 3 | tr -d \' \'";
   $FANS = "sudo $IPMITOOL sdr type \'Fan\' | cut -d \'|\' -f 3 | tr -d \' \'";
   $MEMORY = "sudo $IPMITOOL sdr type \'Memory\' | cut -d \'|\' -f 3 | tr -d \' \'";
   $PSU = "sudo $IPMITOOL sdr type \'Power Supply\' | cut -d \'|\' -f 3 | tr -d \' \'";
   $TEMP = "sudo $IPMITOOL sdr type \'Temperature\' | cut -d \'|\' -f 3 | tr -d \' \'";
   $VOLTAGE = "sudo $IPMITOOL sdr type \'Voltage\' | cut -d \'|\' -f 3 | tr -d \' \'";
   $PDISK = "sudo $IPMITOOL sdr type \'Drive Slot / Bay\' | cut -d \'|\' -f 3 | tr -d \' \'";

   unless ( -x $IPMITOOL ) {
      $status = 1;
      print "CIMC STATUS - missing ipmitool\n";
      exit $status;
   }

}

################################

my @PLATFORM = `$PLATFORM` if ($CHECKONLY =~ m/PLATFORM|ALL/);
my @FANS = `$FANS` if ($CHECKONLY =~ m/FANS|ALL/);
my @MEMORY = `$MEMORY` if ($CHECKONLY =~ m/MEMORY|ALL/);
my @PSU = `$PSU` if ($CHECKONLY =~ m/PSU|ALL/);
my @TEMP = `$TEMP` if ($CHECKONLY =~ m/TEMP|ALL/);
my @VOLTAGE = `$VOLTAGE` if ($CHECKONLY =~ m/VOLTAGE|ALL/);
my @PDISK = `$PDISK` if ($CHECKONLY =~ m/PDISK|ALL/);

chomp @PLATFORM;
chomp @FANS;
chomp @MEMORY;
chomp @PSU;
chomp @TEMP;
chomp @VOLTAGE;
chomp @PDISK;

################################

checkCIMC(\@PLATFORM, "platform") if ($CHECKONLY =~ m/PLATFORM|ALL/);
checkCIMC(\@FANS, "fans") if ($CHECKONLY =~ m/FANS|ALL/);
checkCIMC(\@MEMORY, "memory") if ($CHECKONLY =~ m/MEMORY|ALL/);
checkCIMC(\@PSU, "power supplies") if ($CHECKONLY =~ m/PSU|ALL/);
checkCIMC(\@TEMP, "server temperature") if ($CHECKONLY =~ m/TEMP|ALL/);
checkCIMC(\@VOLTAGE, "VOLTAGE battery") if ($CHECKONLY =~ m/VOLTAGE|ALL/);
checkCIMC(\@PDISK, "physical drives") if ($CHECKONLY =~ m/PDISK|ALL/);



if ( $status == 0 ) {
	print "CIMC STATUS - Okay\n";
	exit 0;
}
elsif ( $status == 1 ) {
	if ( $count > 1 ) { $errmessage = "CIMC STATUS - Multiple Errors"; }
	print "CIMC STATUS - Warning error with $errmessage\n";
	exit 1;
}
elsif ( $status == 2 ) {
	if ( $count > 1 ) { $errmessage = "CIMC STATUS - Multiple Errors"; }
	print "CIMC STATUS - Critical error with $errmessage\n";
	exit 2;
}
else {
	print "CIMC STATUS - Fallthrough unknown error\n";
	exit 3;
}

sub get_vendor {
   my @VENDOR_STRING;
   @VENDOR_STRING = `sudo $DMIDECODE | grep -A 4 'System Information'`;
   foreach $line (@VENDOR_STRING) {
      chomp;
      if ( $line =~ m/Manufacturer:\s+(\w+) .*/) {
         $VENDOR_STRING = $1;
      }
   }
   return $VENDOR_STRING;
}

################################

sub checkCIMC {
   $dataref = shift;
   $message = shift;
   foreach $i ( @{ $dataref } ) {
      unless ( $i =~ m/ok|ns|GOOD/i ) {
         $status = 2;
         $errmessage = $message;
         $count++;
      }
   }
}

################################
