#!/usr/bin/perl -w

use strict;
use warnings;

my @args = ("echo 'Welcome to JABBER' | sendxmpp emrk\@jabber.org");
exec @args;
