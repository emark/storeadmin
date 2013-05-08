#!/usr/bin/perl -w

use strict;
use lib "/home/hosting_locumtest/usr/local/lib/perl5";
use warnings;
use utf8;
use Mojo::UserAgent;
use DBIx::Custom;
use v5.10;
require "pkg/Common.pm";

my %appcfg = Common::GetConfig();
my $dbi = DBIx::Custom->connect(
            dsn => $appcfg{'dsn'},
            user => $appcfg{'user'},
            password => $appcfg{'password'},
            option => {mysql_enable_utf8 => 1}
);

$dbi->do('SET NAMES utf8');

my $orderid = 0;

print "Content-type: text/html\n\n";
print &CheckOrders;

sub CheckOrders(){
my $r = 0;
my $result = $dbi->select(
	table => 'orders',
	column => ['id'],
	where => {status => 0, notify => 0},
);
while (my $row = $result->fetch_hash){
	$orderid = $row->{id};
	$r = $orderid;
	&ChangeStatus();
};
return $r;
};

sub ChangeStatus(){
$dbi->update(
    {notify => 1},
    table => 'orders',
    where => {id => $orderid},
);
};

