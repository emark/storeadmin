package Common 0.1;
use strict;
BEGIN;

&Config('user','password');
sub Config{
#my @selected = @_ || undef;
#print @_;
#exit;
open (DBCONF,"< app.conf") || die "Error open dbconfig file";
my @appconf=<DBCONF>;
close DBCONF;
chomp @appconf;
my %config = ();
my $n = 0;
for (@appconf){
	my ($key,$value) = split('#',$appconf[$n]);
	for (@_){
		config{$key} = $value;

	$n++;
};
print %config;
return %config;
};

#return 1;
END;
