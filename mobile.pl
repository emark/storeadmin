#!/usr/bin/perl -w

use strict;
use lib "/home/hosting_locumtest/usr/local/lib/perl5";
use warnings;
use utf8;
use Mojo::UserAgent;
use DBIx::Custom;
use CGI;
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

my $query = new CGI;
my $cartid = $query->param('cid') || 0;

print "Content-type: text/html\n\n";

my $order = $dbi->select(
	table => 'orders',
	column => ['id','tel','address'],
	where => {cartid => $cartid}
)->fetch_all || undef;

print "<p>Заказ: $order->[0][0]</p><p>$order->[0][1]</p><p><form action=\"http://maps.yandex.ru/\" method=\"get\"><input type=hidden name=text value=\"$order->[0][2]\"\"><input type=\"submit\" value=\"Адрес на карте\"></form></p>";
