#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;
use v5.10;

use CGI qw/:standard/;
use DBIx::Custom;

require 'pkg/Common.pm';

my $cartid = param('cart') || 0;

my %appcfg = Common::GetConfig();
my $dbi = DBIx::Custom->connect(
			dsn => $appcfg{'dsn'},
			user => $appcfg{'user'},
			password => $appcfg{'password'},
            option => {mysql_enable_utf8 => 1}
);

$dbi->do('SET NAMES utf8');

my $result = $dbi->select(
	table => 'orders',
	column => 'id',
	where => {cartid => $cartid, status => 1}
);

my $orderid = 0;
$orderid = $result->value if $result->value;

$result = $dbi->select(
	table => 'items',
	column => ['price','count'],
	where => {cartid => $cartid}
);

my $total_sum = 0;
if ($result){
	while (my $row = $result->fetch){
		$total_sum = $total_sum+($row->[0]*$row->[1]);
	};
};

print header(-charset => 'utf8');
print start_html();

print p("Order #".$orderid);
print p("Total sum: $total_sum");

print end_html;
