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
		&ClearTrash;
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
	print p('<a href="orders.pl?cmd=ClearTrash">Clear Trash</a>') if ($orderstatus == 2);
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
	print <<CSS;
<style>
\@media print{
.noprint{
	display:none;
	}
}
div, table{
	font-family: Arial, serif;
	font-size: 12px;
}
table{
	width:100%;
}
</style>
CSS
	print p('<a href="?" class=noprint>Main page</a>');
	my $cartid = $_[0];
	print '<div id="content">';
	print '<table border=0><tr><td>';
	print '<b>НаСтарт.РФ</b>, интернет-магазин<br />http://настарт.рф<br/>http://www.nastartshop.ru';
	print '</td><td align=right>';
	print '+7 (391) 292-02-29<br />hello@nastartshop.ru<br />ежедневно с 10:00 - 19:00';
	print '</td></tr></table>';
	print '<h2 align=center>Акт передачи товара</h2>';
	my $result = $dbi->select(
		table => 'orders',
		where => {cartid => $cartid}
	);
	$result = $result->fetch_hash;
	print "<p>Номер заказа: $result->{id} ($cartid)<br />";
	print 'Поставщик: ООО "Электронный маркетинг", ИНН 2463213306<br />';
	print "Покупатель: частное лицо $result->{person}, $result->{tel}, $result->{address}";
	print '</p>';
	$result = $dbi->select(
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
    print '<table border=1 cellpadding=5 cellspacing=0>';
	print '<tr><th>№</th><th>Наименование</th><th>Артикул</th><th>Кол-во</th><th>Цена</th><th>Сумма</th></tr>';
	my $n = 1;
	my $total = 0;
    while(my $row = $result->fetch_hash){
        print '<tr>';
		print "<td>$n</td>";
		print "<td>$row->{title}</td>";
		print sprintf ("<td align=center>%06d</td>",$row->{productid});
		print "<td align=right>$row->{count}</td>";
		print "<td align=right>$row->{price}-00</td>";
		print sprintf "<td align=right>%d-00</td>",$row->{count}*$row->{price};
        print '</tr>';
		$n++;
		$total = $total + $row->{count}*$row->{price};
    };
    print '</table>';
	print "<h3>Итого: $total руб. 00 коп.</h3>";
	print p('Товар получен и проверен. Претензий й к ассортименту, количеству, внешнему виду, комплектации товара не имею.');
	print '<table border=0>';
	print '<tr><td>От покупателя: ___________ /</td><td><pre>             </pre></td><td>От поставщика: __________ /</td></tr>';
	print '</table></div>';
	print "<p class=noprint><a href=\"mailer.pl?cartid=$cartid\">Send email notify</a><br /><br /><a href=\"?cmd=ChangeOrderStatus&orderstatus=2&cartid=$cartid\">In Trash</a>";
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

sub ClearTrash(){
	$dbi->delete(
		table => 'orders',
		where => {status => 2}
	);
	print p('Trash were cleared');
	print p('<a href="orders.pl">Return back</a>');
};
