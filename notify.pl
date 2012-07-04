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
use MIME::Lite;
use MIME::Base64;

my $msg = MIME::Lite->new(
	From => 'emrk@alwaysdata.net',
	To => 'sviridenko.maxim@gmail.com',
	Subject => 'Test servioce',
	Data => 'Hello',
);

MIME::Lite->send(
	'smtp',
	'smtp.alwaysdata.com',
	Timeout => 30, 
	AuthUser=> 'emrk@alwaysdata.net', 
	AuthPass => 'qwer123',
);

$msg->send;
