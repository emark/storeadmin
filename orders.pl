#!/usr/bin/perl -w
#===============================================================================
#
#         FILE:  orders.pl
#
#        USAGE:  ./orders.pl  
#
#  DESCRIPTION:  
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  MaximSviridenko (sm), sviridenko.maxim@gmail.com
#      COMPANY:  E-marketing
#      VERSION:  1.0
#      CREATED:  07/02/2012 01:01:47 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use CGI qw/:standard/;
use DBIx::Custom;
use utf8;
use v5.10.1;
use MIME::Lite;


my $basepath = $0;
$basepath =~s/orders\.pl//;
my $conf = $basepath.'app.conf';

open (DBCONF,"< $conf") || die "Error open dbconfig file: $conf";
my @appconf=<DBCONF>;
close DBCONF;
chomp @appconf;

my $dbi = DBIx::Custom->connect(
            dsn => $appconf[0],
            user => $appconf[1],
            password => $appconf[2],
            option => {mysql_enable_utf8=>1}
);

$dbi->do('SET NAMES utf8');

my $cmd = param('cmd') || 'YMLCatalog';
my $notify = param('notify') || 0;

print header(-charset => 'utf-8',
		-type => 'text/html',
		);

if($cmd eq 'ReadItems'){
	&ReadItems(param('orderid'));
}elsif($cmd eq 'ChangeOrderStatus'){
	&ChangeOrderStatus(param('orderid'),param('orderstatus'));
}elsif($cmd eq 'YMLCatalog'){
	&YMLCatalog;
}else{
	&ReadOrders(param('orderstatus'));
};

sub ReadOrders(){
	my $orderstatus = $_[0] || 0;
	my %order_status = ( 
		0 => 'Uncompleted',
		1 => 'Completed',
		2 => 'Deleted',
	);
	foreach my  $key (keys %order_status){
		print "<a href=\"?orderstatus=$key\">$order_status{$key}</a> | ";
	};
	print p('Order status = '.$order_status{$orderstatus});
	my $result = $dbi->select(
		table => 'orders',
		column => [
			'person',
			'tel',
			'email',
			'address',
			'sysdate',
			'id',
			'orderstatus',
			'deliveryid',
			'paymentid',
		],
		where => {'orderstatus' => $orderstatus},
	);
	print '<table border=1>';
	my $table_headers = $result->header;
	print '<tr>';
	foreach my $key (@{$table_headers}){
		print '<th>';
		print $key;
		print '</th>';
	};
	print '<th>Action</th>';
	print '</tr>';
	while(my $row = $result->fetch_hash){
		print '<tr>';
		foreach my $key (@{$table_headers}){
			print '<td>';
			print $row->{$key};
			print '</td>';
		};
		print '<td>';
		print "<a href=\"orders.pl?cmd=ReadItems&orderid=$row->{'id'}\">See items</a> / ";
		print "<a href=\"orders.pl?cmd=ChangeOrderStatus&orderstatus=1&orderid=$row->{'id'}\">Complete</a> / ";
		print "<a href=\"orders.pl?cmd=ChangeOrderStatus&orderstatus=0&orderid=$row->{'id'}\">Uncomplete</a> / ";
		print '</tr>';
		&NotifyOrders if $notify;
	};
	print '</table>';
};

sub ReadItems(){
	print p('<a href="?">See all orders</a>');
	my $orderid = $_[0];
	my $result = $dbi->select(
        table => 'item',
        column => [
            'productid',
            'title',
            'count',
            'price',
            'orderid',
			'id',
        ],
		where => {'orderid' => $orderid},
    );
    print '<table border=1>';
    my $table_headers = $result->header;
    foreach my $key (@{$table_headers}){
        print '<th>';
        print $key;
        print '</th>';
    };
    while(my $row = $result->fetch_hash){
        print '<tr>';
        foreach my $key (@{$table_headers}){
            print '<td>';
            print $row->{$key};
            print '</td>';
        };
        print '</tr>';
    };
    print '</table>';
	print p("<a href=\"?cmd=ChangeOrderStatus&orderstatus=2&orderid=$orderid\">Delete order</a>");
};

sub ChangeOrderStatus(){
	my $orderid = $_[0];
	my $orderstatus = $_[1];
	$dbi->update(
		{orderstatus => $orderstatus},
		table => 'orders',
		where => {id => $orderid}
	);
	print p('Order status changed');
	&ReadOrders($orderstatus);
};

sub NotifyOrders(){
	my $msg = MIME::Lite->new(
    	From => 'emrk@alwaysdata.net',
	    To => 'sviridenko.maxim@gmail.com',
    	Subject => 'New orders',
	    Data => 'Hello, check for new orders! http://www.nastartshop.ru/cgi-bin/storeadmin/orders.pl?status=0',
	);

	MIME::Lite->send(
    	'smtp',
	    'smtp.alwaysdata.com',
    	Timeout => 30,
	    AuthUser=> 'emrk@alwaysdata.net',
    	AuthPass => $appconf[3],
	);

	$msg->send;
};

sub YMLCatalog{
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
        table => 'catalog',
        column => [
			'title',
			'url',
		],
        where => {'type' => 0}
    );

	my %categoryid = ();
	my $id = 0;
	while(my $row = $category->fetch_hash){
		$id++;
		my $cattitle = $row->{'title'};
		print YML<<CATEGORY;
<category id="$id">$cattitle</category>
CATEGORY
		$categoryid{$row->{'url'}} = $id;#Set category Id
	};	
    print YML "</categories>\n";
	print YML "<offers>\n";
	
	my $offer = $dbi->select(
		table => 'product',
		column => [
			'id',
			'url',
			'title',
			'price',
			'instore',
			'caturl',
		],
	);
		
	while(my $row = $offer->fetch_hash){
		print YML<<OFFER;
<offer id="$row->{'id'}">
<url>http://www.nastartshop.ru/$row->{'caturl'}/$row->{'url'}.html</url>
<price>$row->{'price'}</price>
<currencyId>RUR</currencyId>
<categoryId type="Own">$categoryid{$row->{'caturl'}}</categoryId>
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
};
