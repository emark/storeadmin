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

my $storename = '';
my $orderid = 0;

&CheckOrders;

sub CheckOrders(){
my $result = $dbi->select(
	table => 'orders',
	column => ['id','tel','storename'],
	where => {status => 0, sms => 0},
);
while (my $row = $result->fetch_hash){
	$orderid = $row->{id};
	$storename = $row->{storename};
	my $tel = $row->{tel};
	&ChangeStatus;
	&SendSMS($tel) if length($tel)>8;
};
};

sub ChangeStatus(){
$dbi->update(
	{sms => 1},
	table => 'orders',
	where => {id => $orderid},
);
};

sub SendSMS(){
my $ua = Mojo::UserAgent->new();
my $tel = $_[0];
my $sender_name = $storename;
my $decode_msg = "%D0%97%D0%B4%D1%80%D0%B0%D0%B2%D1%81%D1%82%D0%B2%D1%83%D0%B9%D1%82%D0%B5.%20%D0%92%D0%B0%D1%88%20%D0%B7%D0%B0%D0%BA%D0%B0%D0%B7%20149%20%D0%BF%D0%BE%D0%BB%D1%83%D1%87%D0%B5%D0%BD.%20%D0%98%D0%BD%D1%84%D0%BE%D1%80%D0%BC%D0%B0%D1%86%D0%B8%D1%8F%20%D0%BF%D0%BE%20%D1%82.%20(391)%20203-03-10";

$ua->get("http://api.sms24x7.ru/?method=push_msg&email=sviridenko.maxim\@gmail.com&password=X53aRU1&sender_name=$sender_name&text=$decode_msg&phone=$tel&api_v=1.0&nologin=true&format=json");
};

sub XMPPNotify(){
my $rcv = $appcfg{jabber};
my @args = "echo 'Noviy zakaz ($orderid)/$storename' | sendxmpp $rcv";
system (@args) == 0 or die "Can't start programm";
};