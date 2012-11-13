#!/usr/bin/perl -w

use strict;
use warnings;
use CGI qw/:standard/;
use DBIx::Custom;
use utf8;
use v5.10.1;
require 'pkg/Common.pm';

my $basepath = $0;
$basepath =~s/orders\.pl//;
my $conf = $basepath.'app.conf';

my %appcfg = Common::GetConfig();
my $dbi = DBIx::Custom->connect(
            dsn => $appcfg{'dsn'},
            user => $appcfg{'user'},
            password => $appcfg{'password'},
            option => {mysql_enable_utf8 => 1}
);

$dbi->do('SET NAMES utf8');

my $cmd = param('cmd') || '';
my $notify = param('notify') || 0;

print header(-charset => 'utf-8',
		-type => 'text/html',
		);

if($cmd eq 'ReadItems'){
	&ReadItems(param('orderid'));
}elsif($cmd eq 'ChangeOrderStatus'){
	&ChangeOrderStatus(param('orderid'),param('orderstatus'));
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
			'status',
			'delivery',
			'payment',
		],
		where => {'status' => $orderstatus},
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
        table => 'items',
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
		{status => $orderstatus},
		table => 'orders',
		where => {id => $orderid}
	);
	print p('Order status changed');
	&ReadOrders($orderstatus);
};
