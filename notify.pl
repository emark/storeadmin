#!/usr/bin/perl -w

use strict;
use lib "/home/hosting_locumtest/usr/local/lib/perl5";
use warnings;
use utf8;
use Mojo::UserAgent;
use DBIx::Custom;
use v5.10;
require 'pkg/Common.pm';

my %appcfg = Common::GetConfig();
my $dbi = DBIx::Custom->connect(
            dsn => $appcfg{'dsn'},
            user => $appcfg{'user'},
            password => $appcfg{'password'},
            option => {mysql_enable_utf8 => 1}
);

$dbi->do('SET NAMES utf8');

my $orderid = 0;
&CheckOrders;

sub CheckOrders(){
my $result = $dbi->select(
	table => 'orders',
	columns => 'id',
	where => { notify => 0 },
);
while (my $row = $result->fetch_hash){
	$orderid = $row->{id};
	print $orderid;
	&SendSMS;
	&ChangeStatus;
};
};

sub ChangeStatus(){
$dbi->update(
	{ notify => 1 },
	table => 'orders',
	where => { id => $orderid },
);
};

sub SendSMS(){
my $ua = Mojo::UserAgent->new();
$ua->get("http://api.sms24x7.ru/?method=push_msg&email=sviridenko.maxim\@gmail.com&password=X53aRU1&text=Order_$orderid&phone=+79082087328&api_v=1.1&nologin=true&satellite_adv=if_exists&format=json");
};
