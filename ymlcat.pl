#!/usr/bin/env perl -w

use strict;
use warnings;
use utf8;
use CGI qw/:standard/;
use DBIx::Custom;
use utf8;
use v5.10;
require 'pkg/Common.pm';

my %cfg = Common::GetConfig();
my $dbi = DBIx::Custom->connect(
            dsn => $cfg{'dsn'},
            user => $cfg{'user'},
            password => $cfg{'password'},
            option => {mysql_enable_utf8=>1}
);

$dbi->do('SET NAMES utf8');

my $catfile = 'upload/utf_catalog.yml';
my @adate = localtime(time);
$adate[5] = $adate[5]+1900;
$adate[4] = $adate[4]+1;
$adate[4] = '0'.$adate[4] if($adate[4]<10);
$adate[3] = '0'.$adate[3] if($adate[3]<10);
my $cdate = $adate[5].'-'.$adate[4].'-'.$adate[3];

open (YML,"> $catfile") || die "Can't open fil: $catfile";
print YML<<HEADER;
<?xml version="1.0" encoding="windows-1251"?>
<!DOCTYPE yml_catalog SYSTEM "shops.dtd">
<yml_catalog date="$cdate 00:01">
<shop>
<name>НаСтарт.рф</name>
<company>ООО &quot;Электронный маркетинг&quot;</company>
<url>http://www.nastartshop.ru/</url>
<currencies>
<currency id="RUR" rate="1" plus="0"/>
</currencies>
HEADER
print YML "<categories>\n";
my $category = $dbi->select(
	table => 'pages',
    column => [
		'title',
		'url'],
	where => {'type' => 0});
my %categoryid = ();
my $id = 0;
while(my $row = $category->fetch_hash){
	$id++;
	my $cattitle = $row->{'title'};
	print YML<<CATEGORY;
<category id="$id">$cattitle</category>
CATEGORY
	#Set category Id
	$categoryid{$row->{'url'}} = $id};	
print YML "</categories>\n";
print YML "<offers>\n";
	
my $offer = $dbi->select(
	table => 'products',
	column => [
		'id',
		'url',
		'title',
		'price',
		'instore',
		'caturl']);

while(my $row = $offer->fetch_hash){
	print YML<<OFFER;
<offer id="$row->{'id'}">
<url>http://www.nastartshop.ru/catalog/$row->{'caturl'}/$row->{'url'}.html</url>
<price>$row->{'price'}</price>
<currencyId>RUR</currencyId>
<categoryId type="Own">$categoryid{$row->{'caturl'}}</categoryId>
<picture>http://www.nastartshop.ru/media/products/thumb/$row->{'url'}.jpg</picture>
<delivery>true</delivery>
<name>$row->{'title'}</name>
</offer>
OFFER
};	

print YML "</offers>\n";
print YML<<FOOTER;
</shop>
</yml_catalog>
FOOTER
close YML;
print "Generated at ".localtime();
