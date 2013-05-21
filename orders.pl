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
	}elsif(/ClearTrash/){
		&ClearTrash;
	}elsif(/Cart/){
		&Cart;
	}elsif(/ReservedProducts/){
		&ReservedProducts;
	}elsif(/StoreView/){
		&StoreView;
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
		4 => 'Archive',
	);
	my @sort = sort {$a <=> $b} keys %order_status;
	foreach my  $key (@sort){
		print "<a href=\"?orderstatus=$key\">$order_status{$sort[$key]}</a> | ";
	};
	print "<a href=\"orders.pl?cmd=ReservedProducts\">Reserved</a> | ";
	print "<a href=\"orders.pl?cmd=Cart\">Cart</a> | ";
	print "<a href=\"orders.pl?cmd=StoreView\">Store</a>";
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
		print "<a href=\"orders.pl?cmd=ChangeOrderStatus&orderstatus=3&cartid=$row->{'cartid'}\">Cls</a> / ";
		print "<a href=\"orders.pl?cmd=ChangeOrderStatus&orderstatus=4&cartid=$row->{'cartid'}\">Arch</a> / ";
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

	my $result = $dbi->select(
		table => 'orders',
		where => {cartid => $cartid}
	);
	$result = $result->fetch_hash;

	my $storename = $result->{storename};
	my %cyr_storename =	(
		nastartshop => 'НаСтарт.РФ',
		papatut => 'Папатут.РФ',
	);

	print '<div id="content">';
	print '<table border=0><tr><td>';
	print "<b>$cyr_storename{$storename}</b>, интернет-магазин<br/>http://www.$storename.ru<br />hello\@$storename.ru";
	print '</td><td align=right>';
	print "<b>+7 (391) 203-03-10 | 292-02-29</b><br />Пн-Пт с 11:00 - 19:00<br />Сб. с 12:00 - 18:00";
	print '</td></tr></table>';
	print '<h2 align=center>Акт приема-передачи товара</h2>';
	print "<p><b>Номер заказа:</b> $result->{id}-$cartid<br />";
	print '<b>Продавец:</b> ООО "Электронный маркетинг", ИНН 2463213306, Красноярск,
ул. Телевизорная,1с9<br />';
	print "<b>Покупатель:</b> частное лицо $result->{person}, $result->{tel}, $result->{address}";
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
	my $total_cost = 0;
    while(my $row = $result->fetch_hash){
		my $cost = $dbi->select(
			table => 'products',
			column => 'cost',
			where => {id => $row->{productid}},
		)->value;
        print '<tr>';
		print "<td align=center>$n</td>";
		print "<td>$row->{title}</td>";
		print sprintf ("<td align=center>%06d</td>",$row->{productid});
		print "<td align=right>$row->{count}</td>";
		print "<td align=right>$row->{price}-00<span align=right class=noprint> / $cost-00</span></td>";
		print sprintf "<td align=right>%d-00<span align=right class=noprint> / %d-00</span></td>",$row->{count}*$row->{price},$row->{count}*$cost;
        print '</tr>';
		$n++;
		$total = $total + $row->{count}*$row->{price};
		$total_cost =$total_cost + $cost * $row->{count};
    };
    print '</table>';
	print "<h3>Итого: $total руб. 00 коп.</h3>";
	print p({class => "noprint"},"Себестоимость: $total_cost");
	print p('<b>Гарантия на товары составляет 6 месяцев со дня продажи, если не указан иной срок.</b>');
	print p('Товар получен и проверен. Претензий к ассортименту, количеству, внешнему виду, комплектации товара не имею.');
	print '<table border=0>';
	print '<tr><td>Покупатель: ___________ /</td><td><pre>             </pre></td><td>Продавец: __________ /</td></tr>';
	print '</table></div>';
	print "<p class=noprint><a href=\"mailer.pl?cartid=$cartid&storename=$storename\">Send email notify</a><br /><br /><a href=\"?cmd=ChangeOrderStatus&orderstatus=2&cartid=$cartid\">In Trash</a>";
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

sub ReservedProducts(){
	print '<h1>Reserved products</h1>';
	print '<p><a href="orders.pl">Return back</a></p>';
	my $result = $dbi->select(
		table => 'items',
		column => [
			'items.title as title',
			'items.count',
			'items.price',
			'items.cartid',
		],
		where => {'orders.status' => 1},
		join => ['left join orders on orders.cartid=items.cartid']
	);
	print '<table border=1><tr><td>Товар</td><td>Колич.</td><td>Цена</td><td>Корзина</td></tr>';
	while(my $row = $result->fetch_hash) {
		print "<tr><td>$row->{title}</td><td>$row->{count}</td><td>$row->{price}</td><td>$row->{cartid}</td></tr>";
	};
	print '</table>';
};

sub StoreView(){
	print '<h1>Products in store</h1>';
    print '<p><a href="orders.pl">Return back</a></p>';
    my $result = $dbi->select(
        table => 'products',
        column => ['id','title','instore','price','cost'],
    );
    print '<table border=1><tr><td>Арт.</td><td>Товар</td><td>Колич.</td><td>Цена с/с</td><td>Цена</td></tr>';
    while(my $row = $result->fetch_hash) {
        print "<tr><td>$row->{id}</td><td>$row->{title}</td><td>$row->{instore}</td><td>$row->{cost}</td><td>$row->{price}</td></tr>";
    };
    print '</table>';

};
