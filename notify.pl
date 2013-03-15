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
&CheckOrders;

sub CheckOrders(){
my $result = $dbi->select(
	table => 'orders',
	column => ['id','tel'],
	where => {status => 0, notify => 0},
);
while (my $row = $result->fetch_hash){
	$orderid = $row->{id};
	my $tel = $row->{tel};
	&SendSMS($tel);
	&ChangeStatus;
};
};

sub ChangeStatus(){
$dbi->update(
	{notify => 1},
	table => 'orders',
	where => {id => $orderid},
);
};

sub SendSMS(){
my $ua = Mojo::UserAgent->new();
my $tel = $_[0];
my $sender_name = 'NaStart';
my $decode_msg = "%D0%A1%D0%BF%D0%B0%D1%81%D0%B8%D0%B1%D0%BE%20%D0%B7%D0%B0%20%D0%B7%D0%B0%D0%BA%D0%B0%D0%B7%20%D0%BD%D0%BE%D0%BC%D0%B5%D1%80%20$orderid.%20%D0%9C%D0%B0%D0%B3%D0%B0%D0%B7%D0%B8%D0%BD%20%D0%9D%D0%B0%D0%A1%D1%82%D0%B0%D1%80%D1%82.%D0%A0%D0%A4%20(391)%2029-202-29";
$ua->get("http://api.sms24x7.ru/?method=push_msg&email=sviridenko.maxim\@gmail.com&password=X53aRU1&sender_name=$sender_name&text=$decode_msg&phone=$tel&api_v=1.0&nologin=true&format=json");
print "$orderid $tel";
};
