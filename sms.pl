#!/usr/bin/perl -w

use strict;
use lib "/home/hosting_locumtest/usr/local/lib/perl5";
use warnings;
use utf8;
use Mojo::UserAgent;
use DBIx::Custom;
use CGI qw/:standard/;
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

print header(-charset => 'utf8', -type => 'text/html');

my $cartid = param('cartid') || 0;

&Test if ($ARGV[0]);

if($cartid){
	&SendSMS($cartid);
}else{
	&CheckOrders;
};

sub CheckOrders(){
my $result = $dbi->select(
	table => 'orders',
	column => ['cartid'],
	where => {status => [0, 1], sms => 0},
);
while (my $row = $result->fetch_hash){
	$cartid = $row->{cartid};
	&SendSMS($cartid);
};
};

sub ChangeStatus(){
$dbi->update(
	{sms => 1},
	table => 'orders',
	where => {cartid => $cartid},
);
};

sub SendSMS(){
my $order = $dbi->select(
	table => 'orders',
	column => ['id','tel'],
	where => {cartid => $cartid},
)->fetch_hash;

my $ua = Mojo::UserAgent->new();
my $tel = $order->{tel};
my $orderid = $order->{id};
my $decode_msg = "%D0%9D%D0%B0%D0%A1%D1%82%D0%B0%D1%80%D1%82.%D0%A0%D0%A4:%20%D0%B2%D0%B0%D1%88%20%D0%B7%D0%B0%D0%BA%D0%B0%D0%B7%20$orderid%20%D0%BF%D1%80%D0%B8%D0%BD%D1%8F%D1%82.%20%D0%9F%D0%BE%D0%B4%D1%80%D0%BE%D0%B1%D0%BD%D0%B5%D0%B5:%2083912920229";

print $ua->get("http://api.sms24x7.ru/?method=push_msg&email=$appcfg{sms24mail}&password=$appcfg{sms24pass}&text=$decode_msg&phone=$tel&api_v=1.1&nologin=true&format=json")->res->body;

&ChangeStatus($cartid);
};

sub Test(){
say 'Sending test';
my $ua = Mojo::UserAgent->new;
print $ua->get("http://api.sms24x7.ru/?method=push_msg&email=$appcfg{sms24mail}&password=$appcfg{sms24pass}&text=Test&phone=+79082087328&api_v=1.1&nologin=true&format=json&test=1")->res->body;
};

