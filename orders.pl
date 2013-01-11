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
my $cartid = param('cartid') || 0;

print header(-charset => 'utf-8',
		-type => 'text/html',
		);

for ($cmd){
	if(/ReadItems/){
		&ReadItems($cartid);
	}elsif(/ChangeOrderStatus/){
		&ChangeOrderStatus(param('cartid'),param('orderstatus'));
	}elsif(/ClearDeleted/){
		&ClearDeleted;
	}elsif(/Cart/){
		&Cart;
	}else{
		&ReadOrders(param('orderstatus'));
	};
};

sub ReadOrders(){
	my $orderstatus = $_[0] || 0;
	my %order_status = ( 
		0 => 'Inbox',
		1 => 'Active',
		2 => 'Trash',
		3 => 'Closed',
	);
	my @sort = sort {$a <=> $b} keys %order_status;
	foreach my  $key (@sort){
		print "<a href=\"?orderstatus=$key\">$order_status{$sort[$key]}</a> | ";
	};
	print "<a href=\"orders.pl?cmd=Cart\">Cart</a>";
	print h1($order_status{$orderstatus});
	my $result = $dbi->select(
		table => 'orders',
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
	print '<th>action</th>';
	print '</tr>';
	while(my $row = $result->fetch_hash){
		print '<tr>';
		foreach my $key (@{$table_headers}){
			print '<td ';
			print 'style="font-weight: bold"' if $cartid == $row->{cartid};
			print '>';
			print $row->{$key};
			print '</td>';
		};
		print '<td>';
		print "<a href=\"orders.pl?cmd=ReadItems&cartid=$row->{'cartid'}\">Items</a> / ";
		print "<a href=\"orders.pl?cmd=ChangeOrderStatus&orderstatus=0&cartid=$row->{'cartid'}\">Ibx</a> / ";
		print "<a href=\"orders.pl?cmd=ChangeOrderStatus&orderstatus=1&cartid=$row->{'cartid'}\">Acv</a> / ";
		print "<a href=\"orders.pl?cmd=ChangeOrderStatus&orderstatus=3&cartid=$row->{'cartid'}\">Cls</a>";
		print '</tr>';
	};
	print '</table>';
	print p('<a href="orders.pl?cmd=ClearDeleted">Clear deleted</a>') if ($orderstatus == 2);
};

sub Cart(){
	print p('<a href="orders.pl">Return back</a>');
	my $result = $dbi->select(
		table => 'cart',
	);
	print '<table border=1>';
	while(my $row = $result->fetch_hash){
	print "<tr><td>$row->{productid}</td><td>".localtime($row->{cartid})."</td><td>$row->{cartid}</td></tr>";
	};
	print '</table>';
};

sub ReadItems(){
	print p('<a href="?">Main page</a>');
	my $cartid = $_[0];
	my $result = $dbi->select(
        table => 'items',
        column => [
            'productid',
            'title',
            'count',
            'price',
			'id',
        ],
		where => {cartid => $cartid},
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
	print p("<a href=\"mailer.pl?cartid=$cartid\">Send email notify</a>");
	print p("<a href=\"?cmd=ChangeOrderStatus&orderstatus=2&cartid=$cartid\">Delete order</a>");
};

sub ChangeOrderStatus(){
	my $cartid = $_[0];
	my $orderstatus = $_[1];
	$dbi->update(
		{status => $orderstatus},
		table => 'orders',
		where => {cartid => $cartid}
	);
	print p('Order status changed');
	&ReadOrders($orderstatus);
};

sub ClearDeleted(){
	$dbi->delete(
		table => 'orders',
		where => {status => 2}
	);
	print p('All deleted orders were cleared');
	print p('<a href="orders.pl">Return back</a>');
};
