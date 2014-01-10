#!/usr/bin/perl -w

use lib "/home/hosting_locumtest/usr/local/lib/perl5";
use warnings;
use utf8;
use Mojo::UserAgent;
use DBIx::Custom;
use CGI qw/:standard/;
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

my $cartid = param('cartid') || 0;
my $rcpt = '';
my $subject = '';
my $mb_txt = '';

print header(-charset => 'utf8', -type => 'text/html');

if($cartid){
	&StatusTemplate($cartid);
}else{
	&CheckAll;
};

sub CheckAll{
my $result = $dbi->select(
	table => 'orders',
	column => ['cartid'],
	where => {status => [0, 1], mailer => 0}
);
while(my $row = $result->fetch){
	$cartid = $row->[0];
	$storename = $row->[1];
	&StatusTemplate($cartid);
};
};

sub SendMail(){
my $ua = Mojo::UserAgent->new();
my $token = '8d104571-9db5-49a4-971e-9b1943f6c3b9';

my $tx = $ua->post('http://api.postmarkapp.com/email' => {'X-Postmark-Server-Token' => $token} => json => {
	From => "hello\@nastartshop.ru",
	To => $rcpt,
	Subject => $subject,
	HtmlBody => '',
	TextBody => $mb_txt,
	ReplyTo => "hello\@nastartshop.ru",
	});
print $tx->res->body;
};

sub StatusTemplate(){
my %dict = (
	courier => 'курьерская доставка (Красноярск)',
	store => "самостоятельно из пунктов самовывоза.\nАдреса и время работы пунктов http://www.nastartshop.ru/about/contacts.html",
	shipping => 'транспортная компания (Россия)',
	cash => 'наличный платеж',
	check => 'банковский перевод',
	yamoney => 'ПС Яндекс.Деньги',
	credit => 'Оплата в кредит',
);

my $result = $dbi->select(
	table => 'items',
	where => {cartid => $cartid},
);
my $items = '';
my $total = 0;
my $discount_base = 0;
my $n = 0;
while(my $row = $result->fetch_hash){
	$n++;
	$items = $items."$n. $row->{title} (арт. $row->{productid}) - $row->{price} руб.\t$row->{count} шт.\t\n";
	$discount_base = $discount_base + $row->{price}*$row->{count} if !$row->{discount};
	$total = $total+($row->{count}*$row->{price});
};

$result = $dbi->select(
	table => 'orders',
	where => {cartid => $cartid},
);
$result = $result->fetch_hash;

my $person = '';
$person = ', '.$result->{person} if (length($result->{person})>0);

$rcpt = $result->{email};
$subject = "Заказ #$result->{id}";

my $discount = '';
if($result->{discount}){
	$discount_rate = $dbi->select(
		column => 'discount',
		table => 'discounts',
		where => {name => $result->{discount}},
	)->value;
	if($discount_rate){
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
	};
}else{
	$total = $total.' руб.';
};

my $comments = '';
$comments = "Комментарий к заказу: $result->{comments}\n" if $result->{comments};

my $address = '';
$address = "Адрес доставки: $result->{address}\n" if $result->{address};

$mb_txt = <<EOF;
Добрый день$person!
Благодарим за обращение в наш магазин.

Номер заказа: $result->{id}

$items---
Итого (без доставки): $total
$comments
Доставка: $dict{$result->{'delivery'}}
$address
Способ оплаты: $dict{$result->{'payment'}}
Реквизиты и инструкцию по оплате вы можете увидеть по ссылке 
http://www.nastartshop.ru/cart/payment/$result->{cartid}/

Все варианты оплаты и доставки заказа:
http://www.nastartshop.ru/about/delivery-and-payment.html

Гарантия на товары составляет 6 месяцев со дня продажи, если не указан иной срок.
Условия предоставления скидок размещены на странице http://www.nastartshop.ru/about/discounts.html
-- 
Интернет-магазин "НаСтарт.РФ"
Мы работаем:
 - Понедельник-Пятница c 11:00 до 18:00
 - Суббота с 12:00 до 16:00
телефон: 8-(391)-203-03-10
почта: hello\@nastartshop.ru
http://www.nastartshop.ru/
EOF

#print $subject;
#print $mb_txt;
#exit;

print "\nCartID: $cartid\nStatus: ";
if($rcpt){
	&SendMail;
}else{
	print 'Empty email';
};
$dbi->update(
	{mailer => 1},
	table => 'orders',
	where => {cartid => $cartid},
);
};
