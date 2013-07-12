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

my $template = param('t') || '';
my $cartid = param('cartid') || 0;

print header(-charset => 'utf-8',
		-type => 'text/html',
		);

for ($template){
	if(/TradeCheck/){
		return exit if !$cartid;
		&TradeCheck($cartid);
	}elsif(/OrderView/){
		return exit if !$cartid;
		&OrderView($cartid);
	}else{
		print p("Print form {$template} not found");	
	};
};

sub OrderView(){
print <<CSS;
<style>
div, table{
    font-family: Arial, serif;
    font-size: 14px;
}
table{
    width:100%;
}
</style>
CSS
	my $order = $dbi->select(
		table => 'orders',
		where => {cartid => $cartid},
	)->fetch_hash;

	my %delivery = (courier => 'Курьером', store => 'Самовывоз', shipping => 'Транспортные компании');
	my %payment = (cash => 'Наличные', check => 'Банк', yamoney => 'Яндекс', credit => 'Оплата в кредит');
	
	print '<div id="content">';
	print p('ООО "Электронный маркетинг" ИНН 2463213306 ОГРН 1092468020743 Юр. адрес: г .Красноярск, ул. Телевизорная, дом 1 строение 9, помещение 31 Телефон: 8 (391) 203-03-10');
	print "<h2 align=center>Накладная № $order->{id}</h2>";
	print p("Заказчик: $order->{person}, $order->{tel}<br />Адрес: $order->{address}<br/>Доставка: $delivery{$order->{delivery}} Оплата: $payment{$order->{payment}}<br/>Комментарий: $order->{comments}");

	my $result = $dbi->select(
        table => 'items',
		where => {cartid => $cartid},
    );

    print '<table border=1 cellpadding=5 cellspacing=0>';
	print '<tr><th>№</th><th>Наименование</th><th>Арт.</th><th>Кол-во</th></tr>';
	my $n = 1;
    while(my $row = $result->fetch_hash){
        print '<tr>';
		print "<td align=center>$n</td>";
		print "<td>$row->{title}</td>";
		print sprintf ("<td align=center>%06d</td>",$row->{productid});
		print "<td align=right>$row->{count}</td>";
        print '</tr>';
		$n++;
    };
    print '</table>';
	print '</div><br/>';
	print '<table>';
	print '<tr><td><b>Покупатель</b></td><td>-----------------</td><td>/_____________/</td></tr>';
	print '<tr><td colspan=3>Товар получен и проверен. Претензий к ассортименту, количеству, внешнему виду, комплектации товара не имею.<br /><br /></td></tr>';
	print '<tr><td><b>Продавец</b></td><td>-----------------</td><td>/_____________/</td></tr>';
	print '</table></div>';
};

sub TradeCheck(){
	print <<CSS;
<style>
div, table{
	font-family: Arial, serif;
	font-size: 12px;
}
table{
	width:100%;
}
</style>
CSS

	my @curdate = localtime(time);
	$curdate[5] = $curdate[5] + 1900;
	$curdate[4] = $curdate[4] + 1;
	$curdate[4] = '0'.$curdate[4] if $curdate[4] < 10;
	$curdate[3] = '0'.$curdate[3] if $curdate[3] < 10;

	my $result = $dbi->select(
		table => 'orders',
		where => {cartid => $cartid}
	);
	$result = $result->fetch_hash;

	print '<div id="content">';
	print '<table border=0><tr><td>';
	print 'ООО "Электронный маркетинг"<br />ИНН 2463213306 ОГРН 1092468020743<br />Юр. адрес: г .Красноярск, ул. Телевизорная,<br />дом 1 строение 9, помещение 31<br />Телефон: 8 (391) 203-03-10';
	print '</td><td align=right>';
	print "Интернет-магазин <b>НаСтарт.РФ</b><br/>http://www.nastartshop.ru<br />";
	print "8 (391) 203-03-10, 292-02-29<br />Пн-Пт с 11:00 - 19:00<br />Сб. с 12:00 - 18:00";
	print '</td></tr></table>';
	print "<h2 align=center>Товарный чек № $result->{id} от $curdate[3].$curdate[4].$curdate[5]г.</h2>";
	print '</p>';
	my $discount = $result->{discount};

	$result = $dbi->select(
        table => 'items',
		where => {cartid => $cartid},
    );

    print '<table border=1 cellpadding=5 cellspacing=0>';
	print '<tr><th>№</th><th>Наименование</th><th>Арт.</th><th>Кол-во</th><th>Цена, руб.</th><th>Сумма, руб.</th><th>Дисконт, %</th></tr>';
	my $n = 1;
	my $total = 0;
	my $discount_base = 0;
    while(my $row = $result->fetch_hash){
        print '<tr>';
		print "<td align=center>$n</td>";
		print "<td>$row->{title}</td>";
		print sprintf ("<td align=center>%06d</td>",$row->{productid});
		print "<td align=right>$row->{count}</td>";
		print "<td align=right>$row->{price}-00</td>";
		print sprintf "<td align=right>%d-00</td>",$row->{count}*$row->{price};
		print "<td align=right>$row->{discount}</td>";
        print '</tr>';
		$n++;
		$total = $total + $row->{count}*$row->{price};
		$discount_base = $discount_base + $row->{price}*$row->{count} if !$row->{discount};
    };
    print '</table>';
	print '<p><center><b>Наличие кассового чека обязательно</b></center></p>';
	
	if($discount){
		my $discount_rate = $dbi->select(
			column => 'discount',
			table => 'discounts',
			where => {name => $discount},
		)->value;
		my $discount_sum = 0;
		if ($discount_rate < 1){
			$discount_sum = sprintf("%d",$discount_base*$discount_rate);
			$discount_rate = $discount_rate*100;
			$discount_rate = $discount_rate.'%';
		}else{
			$discount_sum = $discount_rate;
			$discount_rate = $discount_rate.' руб.';
		};
		$total = $total-$discount_sum;
		$total = "$total руб. в том числе скидка $discount_rate",
	}else{
		$total = $total.' руб. 00 коп.';
	};
	
	print "<h3>Итого: $total </h3>";
	print p("Гарантия на товары составляет 6 месяцев со дня продажи, если не указан иной срок.</b><br />Условия предоставления скидок размещены на странице http://www.nastartshop.ru/about/discounts.html");
	print '<table>';
	print '<tr><td><b>Покупатель</b></td><td>-----------------</td><td>/_____________/</td></tr>';
	print '<tr><td colspan=3>Товар получен и проверен. Претензий к ассортименту, количеству, внешнему виду, комплектации товара не имею.<br /><br /></td></tr>';
	print '<tr><td><b>Продавец</b></td><td>-----------------</td><td>/_____________/</td></tr>';
	print '</table></div>';
};