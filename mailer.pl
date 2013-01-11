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

print header(-charset => 'utf8', -type => 'text');

if($cartid){
	&StatusTemplate($cartid);
}else{
	&CheckAll;
};

sub CheckAll{
my $result = $dbi->select(
	table => 'orders',
	column => 'cartid',
	where => {status => 0, mailer => 0}
);
while(my $row = $result->fetch){
	$cartid = $row->[0];
	&StatusTemplate($cartid);
};
};

sub SendMail(){
my $ua = Mojo::UserAgent->new();
my $tx = $ua->post_json('http://api.postmarkapp.com/email'=> {
	From => 'hello@nastartshop.ru',
	To => $rcpt,
	Bcc => 'hello@nastartshop.ru',
	Subject => $subject,
	HtmlBody => '',
	TextBody => $mb_txt,
	ReplyTo => 'hello@nastartshop.ru',
} => {'X-Postmark-Server-Token' => '8d104571-9db5-49a4-971e-9b1943f6c3b9'});
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
);

my $result = $dbi->select(
	table => 'items',
	where => {cartid => $cartid},
);
my $items = '';
my $total = 0;
while(my $row = $result->fetch_hash){
	$items = $items."$row->{title} - $row->{price} руб.\t$row->{count} шт.\t\n";
	$total = $total+($row->{count}*$row->{price});
};


$result = $dbi->select(
	table => 'orders',
	where => {cartid => $cartid},
);
$result = $result->fetch_hash;

$rcpt = $result->{email};
$subject = "Заказ #$result->{id}";
my $comments = '';
$comments = "Комментарий к заказу: $result->{comments}\n" if $result->{comments};
my $address = '';
$address = "Адрес доставки: $result->{address}\n" if $result->{address};
$mb_txt = <<EOF;
Добрый день!
Благодарим за обращение в наш магазин.

Номер заказа: $result->{id}
$items---
Итого (без доставки): $total руб.
$comments
Доставка: $dict{$result->{'delivery'}}
$address
Способ оплаты: $dict{$result->{'payment'}}
Реквизиты и инструкцию по оплате вы можете увидеть по ссылке 
http://www.nastartshop.ru/cart/payment/$result->{cartid}/

Все варианты оплаты и доставки заказа:
http://www.nastartshop.ru/about/delivery-and-payment.html
-- 
Интернет-магазин "НаСтарт.РФ"
ежедневно c 10:00 до 19:00
тел.: +7 (391) 292-02-29
почта: hello\@nastartshop.ru
http://настарт.рф/
http://www.nastartshop.ru/
EOF
#print $subject;
#print $mb_txt;

print "\nCartID: $cartid\nStatus: ";
if($rcpt){
	#&SendMail;
}else{
	print 'Empty email';
};
$dbi->update(
	{mailer => 1},
	table => 'orders',
	where => {cartid => $cartid},
);
};
