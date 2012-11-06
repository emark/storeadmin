#!/usr/bin/perl -w

use strict;
use warnings;
use CGI qw/:standard/;
use DBIx::Custom;
use utf8;
use v5.10;
require 'pkg/Common.pm';

my %appcfg = Common::GetConfig();
my $dbi = DBIx::Custom->connect(
			dsn => $appcfg{'dsn'},
			user => $appcfg{'user'},
			password => $appcfg{'password'},
            option => {mysql_enable_utf8 => 1}
);

$dbi->do('SET NAMES utf8');

my @schema = <schema/*>;
my @schema_tpl = '';
my $src_table = '';

#get cgi variables
my $file_handle = upload('source') || undef;
my $export = param('export') || undef;
#select line break characters
my $lb = param('linebreak') || undef;

if($export){
	$src_table = $export;
	$src_table=~s/schema\///;
	print header(
		-type => 'text/csv',
		-charset => 'utf-8',
		-attachment => $src_table.'.csv',
	);
	&Export;
}else{
	print header(
		-charset => 'utf-8',
		-type => 'text/html',
	);
    print start_html(-title => 'Data update manager');
	print h1('Data update manager');
	print p('Import data: CSV => DB');
    print start_form(-action => 'update.pl',-method => 'post');
    print filefield(-name => 'source');
    print checkbox(-name => 'linebreak',-value => 1, -label => 'OS Windows');
    print submit(-value => 'Import');
    print end_form;
	print p('Export data: DB => CSV');
    print start_form(-action => 'update.pl', -method => 'post');
    print popup_menu(-name => 'export', -values => ['',@schema]);
    print submit(-value => 'Export');
    print end_form;
    Import();
    print p('<a href="/">Open domain</a>');
    print end_html;
};

sub GetSchema(){
open (SCHEMA,"< $_[0]") || die "Can't load schema file";
@schema_tpl = <SCHEMA>;
close SCHEMA;
chop @schema_tpl};

sub Import(){
if($file_handle){
	my @source_file = <$file_handle>;
	my %counter = (update => 0, insert => 0); #counter for actions
	#drop column captions
	my $schema_upload = shift @source_file;
	chop $schema_upload;
	open (WFILE,"> upload/source.csv") || die "Can't open source file for writing";
	foreach my $key(@source_file){
		print WFILE "$key"};
	close WFILE;
	foreach my $key(@schema){
		&GetSchema($key);
		my $schema_tpl = join(';',@schema_tpl);
		if ($schema_tpl eq $schema_upload){
			$src_table = $key;
		    $src_table=~s/schema\///;
			open(RFILE,"< upload/source.csv") || die "Can't open source file for reading";
			while(<RFILE>){
				chop $_;
				chop $_ if $lb;
				my @import_data = split(';',$_);
				my $data_structure = {};
				my $n=0;
				foreach my $key(@schema_tpl){
					$data_structure->{$key} = $import_data[$n];
					$n++};
				my $id = $data_structure->{'id'} || 0;
				if ($id){
					$dbi->update(
						$data_structure,
						table => $src_table,
						where => {id => $id});
					$counter{'update'}++}
				else{
					$dbi->insert(
						$data_structure,  
	        	        table => $src_table);
					$counter{'insert'}++}};
			close RFILE}};	
	print p("Statistics: update=$counter{'update'}, insert=$counter{'insert'}")}};

sub Export(){
&GetSchema($export);
print join(';',@schema_tpl);
print "\n";
my $products = $dbi->select(
	table => $src_table,
	column => [@schema_tpl]);
while(my $row = $products->fetch_hash){
	foreach my $key (@schema_tpl){
		print $row->{$key};
		print ';'};
	print "\n"}};
