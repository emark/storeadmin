package Common 0.1;
use strict;
BEGIN;

sub GetConfig{
my %Cfg;
open (DBCONF,"< app.conf") || die "Error open dbconfig file";
while(<DBCONF>){
my ($key,$value) = split('#',$_);
chop $value;
$Cfg{$key} = $value};
close DBCONF;
return %Cfg};

return 1;
END;
