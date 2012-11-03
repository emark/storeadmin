package Common 0.1;
BEGIN;

&Config('user','password');
sub Config{
#my @selected = @_ || undef;
print $selected[0];
open (DBCONF,"< app.conf") || die "Error open dbconfig file";
my @appconf=<DBCONF>;
close DBCONF;
chomp @appconf;
my %config = ();
my $n = 0;
for (@appconf){
	my ($ckey,$cvalue) = split('#',$key);
	$config{$ckey} = $cvalue;
	
};
print %config;
return %config;
};

#return 1;
END;
