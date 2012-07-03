#!/usr/bin/perl -w
#===============================================================================
#
#         FILE:  notify.pl
#
#        USAGE:  ./notify.pl  
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
#      CREATED:  07/03/2012 06:04:30 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use utf8;
use v5.10.1;

use Net::SMTP;

my $smtp = Net::SMTP->new(
		Host => 'smtp.alwaysdata.com',
		Debug => 1,
	);

$smtp->auth('emrk@alwaysdata.net','qwer123');
$smtp->mail('emrk@alwaysdata.net');
$smtp->to('sviridenko.maxim@gmail.com');

$smtp->data();
$smtp->datasend('To: sviridenko.maxim@gmail.com');
$smtp->datasend("\n\n");
$smtp->datasend("Hello World!\n");
$smtp->dataend();

$smtp->quit;
