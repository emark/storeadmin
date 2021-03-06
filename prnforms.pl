#!/usr/bin/perl -w

use utf8;
use strict;
use lib "/home/hosting_locumtest/usr/local/lib/perl5";
use warnings;
use CGI qw/:standard/;
use DBIx::Custom;
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
print start_html(-title=>'Печатная форма');

return exit if !$cartid;

for ($template){
	if(/TradeCheck/){
		&TradeCheck;
	}elsif(/OrderView/){;
		&OrderView;
	}elsif(/Review/){
		&Review;
	}elsif(/CreditOrder/){
		&CreditOrder;
	}elsif(/RecipientInformation/){
		&RecipientInformation;
	}elsif(/TradeOrder/){
		&TradeOrder;
	}elsif(/Articul/){
		&PrintArticul;
	}else{
		print p("Print form {$template} not found");	
	};
};

print end_html;

sub RecipientInformation(){
	my $result = $dbi->select(
        table => 'orders',
        columns => ['person','address','tel','id'],
        where => {cartid => $cartid},
    );
    my $order = $result->one;

print <<CSS;
<style>
div, table, input{
    font-family: Arial, serif;
    font-size: 22px;
}
table{
    width:100%;
}
</style>
CSS

print<<HTML;
<div id="Content">
Отправитель: ООО "Эмарк", <br/>ОГРН 1092468020743, ИНН 2463213306<br/>
660028, Красноярск, Красноярский край, Россия,<br/>
Телевизорная ул., д. 1, корп. 9<br/>
Почтовый адрес: 660028, г. Красноярск, а/я 11939<br/>
Телефон: 8 (391) 203-03-10, 292-02-29<br/>
Почта: mailbox\@emrk.ru<br/>
<hr/>
Получатель: $order->{person}, $order->{tel}<br/>
Адрес: $order->{address}<br/>
Данные заказа: $order->{id}-$cartid<br/>
Место <input type=text size=2> из <input type=text size=2>
</div>
HTML
};

sub CreditOrder(){
	my $result = $dbi->select(
		table => 'orders',
		columns => ['id','rvcode'],
		where => {cartid => $cartid},
	);
	my $order = $result->one;
	my @orderdate = localtime($cartid);
	my $items = $dbi->select(
		table => 'items',
		where => {cartid => $cartid},
	);

	my %category = ();
	$result = $dbi->select(
		table => 'catalog',
    		column => ['catalog.caption as caption','products.id as productid'],
    		join => [
			{
			clause => 'inner join products on catalog.url = products.caturl',
			table => ['catalog', 'products'],
			}
    		]
	);
	while (my $row = $result->fetch_hash){
		$category{$row->{productid}} = $row->{caption};
	};

	my $discount = $dbi->select(
		column => 'discount',
		table => 'discounts',
		where => {name => $order->{discount}},
	)->value;

	my $totalsum = 0;
	my $firstpayment = 0;
	my %items = ();

	while (my $item = $items->fetch_hash){
		my $pcsprice = $item->{price};
	
		if($discount && $item->{discount} == 0){
	
			if($discount <1){
			
				my $discount_pcsprice = sprintf("%d",$item->{price}*$discount);
				$pcsprice = $pcsprice - $discount_pcsprice;
			};
		};

		$totalsum = $totalsum + $pcsprice*$item->{count};

		$items{$item->{productid}} = "Наименование: $item->{title}\nКатегория товара: $category{$item->{productid}}\nКоличество: $item->{count}\nЦена за единицу: $pcsprice.00\n";
	};

	$totalsum = $totalsum-$discount if ($discount > 1);

	$firstpayment = sprintf("%d",$totalsum/10);
	
	print '<pre>';
print<<HTML;
Тема: Интернет-заказ www.nastartshop.ru № $order->{id}. ТТ: 278594. POSORDER3

[Параметры заявки]
Код ТТ: 278594
Адрес сайта: www.nastartshop.ru
Название ТО: ООО "Электронный маркетинг"
Номер заказа: $order->{id}
Кредитный продукт: 10-10-10
Срок кредита: 10
Первоначальный взнос: $firstpayment
Способ получения: Самовывоз
Комментарий клиента:
Сумма заказа: $totalsum.00

[Персональные данные клиента]
Фамилия: $order->{person}
Имя: 
Отчество: 
Дата рождения: 
Серия и номер паспорта: 
Электронная почта:
Контактный телефон: $order->{tel}
HTML

my $n = 0;
foreach my $key (keys %items){
	$n++;
	print "\n[Товар$n]\n";
	print $items{$key};
};

print<<HTML;

[Служебные данные]
ФИО сотрудника ТО: Свириденко М. А.
Телефон для информирования ТО: +7 (908) 208-7328
E-mail для информирования ТО: mailbox\@emrk.ru
Код агента ТО:
Кодировка: WIN-1251
HTML
	print '</pre>';
};

sub Review(){
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

	my $result = $dbi->select(
		table => 'orders',
		columns => ['id','rvcode'],
		where => {cartid => $cartid},
	)->one;
	my @orderdate = localtime($cartid);
	$orderdate[5] = $orderdate[5]+1900;
	$orderdate[4] = $orderdate[4]+1;
	$orderdate[4] = '0'.$orderdate[4] if $orderdate[4] < 10;
	$orderdate[3] = '0'.$orderdate[3] if $orderdate[3] < 10;
	
	print '<div id="content">';	
	print h2('<center>КУПОН НА 300 РУБЛЕЙ</center>');
	print h3('<center><i>Как активировать купон</i></center>');
print<<HTML;
<ol>
<li>Зайдите в интернет-магазин НаСтарт.РФ в раздел “Отзывы”. Нажмите кнопку “Добавить отзыв”</li>
<li>Напишите свой отзыв о покупке и оцените работу магазина. Укажите номер заказа <b>$result->{id}</b> и код активации купона <b>$result->{rvcode}</b></li>
</ol>
HTML
	print h3('<center><i>Правила применения купона</i></center>');
print <<HTML;
<ul>
<li>При следующем заказе укажите промо-код <b>$result->{id}$result->{rvcode}</b> в специальном поле на странице оформления интернет-магазина.</li>
<li>Промо-код можно использовать только один раз.</li>
<li>Максимальная скидка по купону не может быть более 50% от суммы заказа</li>
<li>Период использования активированного купона ограничен сроком проведения текущей акции.</li>
</ul>
Полные правила и условия предоставления скидок читайте на странице Скидки интернет-магазина по адресу http://www.nastartshop.ru/about/discounts.html
HTML
	print '<div>';
};

sub OrderView(){
print <<CSS;
<style>
div, table{
    font-family: Arial, serif;
    font-size: 12px;
}
.small{font-size:10px}
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
	print p({-class => 'small'},'ООО "Электронный маркетинг" ОГРН 1092468020743, т. 8(391)203-03-10');
	print "<h3 align=left>Накладная № $order->{id}</h3>";
	print table({-width=>100},
		Tr({-valign => 'top'},[
			td(["Заказчик: $order->{person}, $order->{tel}<br />Адрес: $order->{address}<br/>Доставка: $delivery{$order->{delivery}} Оплата: $payment{$order->{payment}}<br/>Комментарий: $order->{comments}",'Кол. мест:<br/><br/>Маркер']),
		]),
	);

	my $items = $dbi->select(
        table => 'items',
		where => {cartid => $cartid},
    );
	
	my $storage = $dbi->select(
		table => 'products',
		columns => ['id','storage'],
	)->fetch_hash_all;

	my %storage = ();
	foreach my $key (@{$storage}){
		$storage{$key->{id}} = $key->{storage};
	};

    print '<table border=1 cellpadding=5 cellspacing=0>';
	print '<tr><th>№</th><th>Наименование</th><th>Арт.</th><th>Склад</th><th>Кол-во</th></tr>';
	my $n = 1;
    while(my $row = $items->fetch_hash){
        print '<tr>';
		print "<td align=center>$n</td>";
		print "<td>$row->{title}</td>";
		print "<td align=center>$row->{productid}</td>";
		print "<td align=right>$storage{$row->{productid}}</td>";
		print "<td align=right>$row->{count}</td>";
        print '</tr>';
		$n++;
    };
    print '</table>';
	print '<br/>';
	print '<table border=0>';
	print '<tr><td><b>Получил</b></td><td>_____________</td><td>/_____________/</td></tr>';
	print '<tr><td colspan=3>Товар получен и проверен. Претензий к ассортименту, количеству, внешнему виду, комплектации товара не имею.<br /><br /></td></tr>';
	print '<tr><td><b>Передал</b></td><td>_____________</td><td>/_____________/ Дата/Время: ______ /_____ </td></tr>';
	print '</table>';
	if($order->{delivery} eq 'courier'){
		print<<SERVICEINFO;
<br/>
<hr>
<table border=0>
<tr valign=top><td>Заказ:<br/><br/>Доставка:<br/><br/>Установка:<br/><br/>Итого:</td><td>Сдача:<br/><br/>с суммы:</td><td align=center><img src=\"http://chart.googleapis.com/chart?cht=qr&chs=150x150&chl=http://store.emrk.ru/cgi-bin/storeadmin/mobile.pl?cid=$cartid\"><br/>$cartid</td></tr>
</table>
SERVICEINFO
	};
	print '</div>';
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
	print p('Интернет-магазин <b>НаСтарт.РФ</b> http://www.nastartshop.ru, 8 (391) 203-03-10, 292-02-29<br/>ООО "Электронный маркетинг" ИНН 2463213306, Юр. адрес: г. Красноярск, ул. Телевизорная, 1с9, 31');
	print "<h2 align=center>Товарный чек № $result->{id} от $curdate[3].$curdate[4].$curdate[5] г.</h2>";
	print '</p>';

	my $discount_rate = 0;
	$discount_rate = $dbi->select(
			column => 'discount',
			table => 'discounts',
			where => {name => $result->{discount}},
	)->value if ($result->{discount});

	$result = $dbi->select(
        table => 'items',
		where => {cartid => $cartid},
    );

    print '<table border=1 cellpadding=5 cellspacing=0>';
	print '<tr><th>№</th><th>Наименование</th><th>Арт.</th><th>Кол-во</th><th>Дисконт, %</th><th>Цена, руб.</th><th>Скидка, %</th><th>Сумма, руб.</th></tr>';
	my $n = 1;
	my $total = 0;
	my $base_sum = 0;
	my $discount_base = 0;
	my $item_discount_sum = 0;
    while(my $row = $result->fetch_hash){
        print '<tr>';
		print "<td align=center>$n</td>";
		print "<td>$row->{title}</td>";
		print sprintf ("<td align=center>%06d</td>",$row->{productid});
		print "<td align=right>$row->{count}</td>";
		print "<td align=right>$row->{discount}</td>";
		print "<td align=right>$row->{price}-00</td>";
		print '<td align=right>',$row->{discount} || $discount_rate > 1 ? 0 : $discount_rate*100,'</td>';
		print sprintf "<td align=right>%d-00</td>",$row->{count}*$row->{price};
        print '</tr>';
		$n++;
		$total = $total + $row->{count}*$row->{price};
		$discount_base = $discount_base + $row->{price}*$row->{count} if !$row->{discount};
		$item_discount_sum = $item_discount_sum + $row->{price}*$row->{discount}/100 if $row->{discount};
    };
	print "<tr><td colspan=7 align=right><b>Итого без скидки:</b></td><td align=right><b>$total-00</b></td></tr>";
	
	if($discount_rate){
		my $discount_sum = 0;
		if ($discount_rate < 1){
			$discount_sum = sprintf("%d",$discount_base*$discount_rate);
			#$discount_rate = $discount_rate*100;
			#$discount_rate = $discount_rate.'%';
		}else{
			$discount_sum = $discount_rate;
			#$discount_rate = $discount_rate.' руб.';
		};
		$total = $total-$discount_sum;
		print "<tr><td colspan=7 align=right><b>Сумма скидки:</b></td><td align=right><b>$discount_sum-00</b></td></tr>";
		#$total = "$total руб. в том числе скидка $discount_rate",
	}else{
		#$total = $total.' руб. 00 коп.';
	};

    print '</table>';
	print h3("Сумма к оплате: $total руб. 00 коп.");
	print "<p>Гарантия на товары составляет 6 месяцев со дня продажи, если не указан иной срок.</b><br />Скидка не распространяется на товары с дисконтом. Условия предоставления скидок размещены на странице <b>http://www.nastartshop.ru/about/discounts.html</b>";
	print '</p><table>';
	print '<tr><td><b>Продавец</b></td><td>-----------------</td><td>/_____________/</td></tr>';
	print '</table></div>';
};

sub TradeOrder(){
	my @curdate = localtime(time);
	$curdate[5] = $curdate[5] + 1900;
	$curdate[4] = $curdate[4] + 1;
	$curdate[4] = '0'.$curdate[4] if $curdate[4] < 10;
	$curdate[3] = '0'.$curdate[3] if $curdate[3] < 10;
	my @months = ('','января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря');

	my $order = $dbi->select(
		table => 'orders',
		where => {cartid => $cartid}
	)->fetch_hash;

	print '<div id="content">';
	print p({-align=>'right'},"Приложение №1 <br/>к договору поставки № П-$order->{id} <br/> от \"$curdate[3]\" $months[$curdate[4]] $curdate[5] г.");
	print p({-align=>"center"},'Заказ на поставку товаров');
	my $discount_rate = 0;
	$discount_rate = $dbi->select(
			column => 'discount',
			table => 'discounts',
			where => {name => $order->{discount}},
	)->value if ($order->{discount});

	my $items = $dbi->select(
        table => 'items',
		where => {cartid => $cartid},
    );

    print '<table border=1 cellpadding=5 cellspacing=0 width="100%" style="font-size:12px;font-family:Arial;">';
	print '<tr><th>№</th><th>Наименование</th><th>Арт.</th><th>Кол-во</th><th>Дисконт, %</th><th>Цена, руб.</th><th>Скидка, %</th><th>Сумма, руб.</th></tr>';
	my $n = 1;
	my $total = 0;
	my $base_sum = 0;
	my $discount_base = 0;
	my $item_discount_sum = 0;
    while(my $row = $items->fetch_hash){
        print '<tr>';
		print "<td align=center>$n</td>";
		print "<td>$row->{title}</td>";
		print sprintf ("<td align=center>%06d</td>",$row->{productid});
		print "<td align=right>$row->{count}</td>";
		print "<td align=right>$row->{discount}</td>";
		print "<td align=right>$row->{price}-00</td>";
		print '<td align=right>',$row->{discount} || $discount_rate > 1 ? 0 : $discount_rate*100,'</td>';
		print sprintf "<td align=right>%d-00</td>",$row->{count}*$row->{price};
        print '</tr>';
		$n++;
		$total = $total + $row->{count}*$row->{price};
		$discount_base = $discount_base + $row->{price}*$row->{count} if !$row->{discount};
		$item_discount_sum = $item_discount_sum + $row->{price}*$row->{discount}/100 if $row->{discount};
    };
	print "<tr><td colspan=7 align=right><b>Итого без скидки:</b></td><td align=right><b>$total-00</b></td></tr>";
	#print sprintf "<tr><td colspan=7 align=right><b>В т. ч. дисконт*:</b></td><td align=right><b>%d-00</b></td></tr>",$item_discount_sum if $item_discount_sum;
	
	if($discount_rate){
		my $discount_sum = 0;
		if ($discount_rate < 1){
			$discount_sum = sprintf("%d",$discount_base*$discount_rate);
			#$discount_rate = $discount_rate*100;
			#$discount_rate = $discount_rate.'%';
		}else{
			$discount_sum = $discount_rate;
			#$discount_rate = $discount_rate.' руб.';
		};
		$total = $total-$discount_sum;
		print "<tr><td colspan=7 align=right><b>Сумма скидки:</b></td><td align=right><b>$discount_sum-00</b></td></tr>";
		#$total = "$total руб. в том числе скидка $discount_rate",
	}else{
		#$total = $total.' руб. 00 коп.';
	};

    print '</table>';
	print p("Общая сумма заказа $total (_____________________________________________________<br/><br/>____________________________________________________________) руб. 00 коп.");
	
	my $predoplata = sprintf("%d",$total*30/100);
	print p("Сумма предварительной оплаты: $predoplata руб. 00 коп");
	print p("Дата поставки товара не позднее \"$curdate[3]\" $months[$curdate[4]+1] $curdate[5] г.");

	print "<p>Гарантия на товары составляет 6 месяцев со дня продажи, если не указан иной срок.</b><br />Скидка не распространяется на товары с дисконтом. Условия предоставления скидок размещены на интернет-странице по адресу http://www.nastartshop.ru/about/discounts.html";
	print '</p><table width=100%>';
	print '<tr><td>Поставщик:<br/><br/>_____________ /__________________</td><td>Покупатель:<br/><br/>_____________ / '.$order->{person}.'</td></tr>';
	print '</table></div>';
};

sub PrintArticul {

	my @id = param('id');
	my @title = param('title');
	my @url = param('url');
	my @caturl = param('caturl');
	my @count = param('count');
	my $max_cols = param('max_cols'); #Empty value for auto settings

	my $n = 0;
	my $count_total = 0;
	my %articul = ();
	my $col = 0;
	my $tip = 'Совет: ';

	foreach my $key (@id){
		
		if ($count[$n] > 0){
		
			$articul{$key} = {
				'title' => $title[$n],
				'url' => 'http://www.nastartshop.ru/catalog/'.$caturl[$n].'/'.$url[$n].'.html',
				'count' => $count[$n],
			};
				
			$count_total = $count_total+$count[$n];
		};

		$n++;
	};

	#Selection page format
	if ($count_total <= 9){ #Page format A5
	
		$tip = $tip."рекомендуется выбрать формат страницы А5";
		$max_cols = 3 unless $max_cols;
	}else{ #Page format 
	
		$tip = $tip."рекомендуется выбрать формат страницы А4";
		$max_cols = 5 unless $max_cols;
	};

	print "<script script type=\"text/javascript\">alert ('$tip');</script>";

	print '<table style="border-collapse: collapse">';

	foreach my $id (keys %articul){
	
		$n = 0;
		while ($n < $articul{$id}{count}){

			print "\n<tr>" if $col == 0;
			print '<td style="border: 1px solid; text-align: center; vertical-align: top; font-family: Arial; padding: 2px">';
			print "<h3>$id</h3>$articul{$id}{title}<br><img src=\"http://chart.googleapis.com/chart?cht=qr&chs=100x100&chl=$articul{$id}{url}\">";
			print '</td>';

			$col++;
			if ($col == $max_cols) {

				print "\n</tr>";
				$col = 0;
			};
		
			$n++;
		};


	};

	print '</table>';
};
