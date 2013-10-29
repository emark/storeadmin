#!/usr/bin/perl -w

use strict;
use warnings;
use lib "/home/hosting_locumtest/usr/local/lib/perl5";
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
my $duplicates = param('duplicates') || undef;
my $lb = param('linebreak') || undef;
my $lastmod = param('lastmod') || undef;
my $allcolumns = param('allcolumns') || undef;
my $editschema = param('editschema') || undef;
my $schemacontent = param('schemacontent') || undef;

#Developer zone
#exit;

if($export){
	$src_table = $export;
	$src_table=~s/schema\///;
	print header(
		-type => 'text/csv',
		-charset => 'utf-8',
		-attachment => $src_table.'.csv',
	);
	&Export();
}else{
	print header(
		-charset => 'utf-8',
		-type => 'text/html',
	);
    print start_html(-title => 'Data update manager');
	print h1('Data update manager');
    print p('<a href="http://'.$ENV{HTTP_HOST}.'">http://'.$ENV{HTTP_HOST}.'</a>');
	print p('Import data: DB <= CSV');
    print start_form(-action => 'update.pl',-method => 'post');
    print filefield(-name => 'source');
	print checkbox(-name => 'lastmod', -value => 1,-label => 'Refresh date');
	print checkbox(-name => 'duplicates',-value => 1,-label => 'Check for URL duplicates');
    print checkbox(-name => 'linebreak',-value => 1,-label => 'OS Windows');
    print submit(-value => 'Import');
    print end_form;
	print hr;
	print p('Export data: DB => CSV');
    print start_form(-action => 'update.pl', -method => 'post');
    print popup_menu(-name => 'export', -values => [@schema]);
	print checkbox(-name => 'allcolumns', -value => 1, -label => 'Export all columns');
    print submit(-value => 'Export');
    print end_form;
	&SchemaEdit;
    &Import();
	print p('Script executed at '.localtime);
    print end_html;
};

sub SchemaEdit(){
print hr;
print p('Schema editor');

if ($editschema){
	if($schemacontent){
		my @tmp = split("\x0D\x0A",$schemacontent);#Escape URL CRLF
		$schemacontent = join("\n",@tmp);
		open(SCHEMA,"> $editschema") || die "Can't write to file: $editschema";
		print SCHEMA $schemacontent;
		print SCHEMA "\n";
		close SCHEMA;
		print p("Write schema content to $editschema");
		
	}else{
		&GetSchema($editschema);
		$schemacontent = join("\n",@schema_tpl);
	};
};

print start_form(-action => 'update.pl', -method => 'post');
print popup_menu(-name => 'editschema', -values => [@schema]);
print submit(-value => 'Open');
print end_form;
print start_form(-action => 'update.pl', -method => 'post');
print textfield(-name => 'editschema', -value=> $editschema);
print p;
print textarea(-name => 'schemacontent', -default => $schemacontent, -rows => 8);
print '<br />';
print submit(-value => 'Save');
print end_form;
};

sub GetSchema(){
unless($allcolumns){
	open (SCHEMA,"< $_[0]") || die "Can't load schema file: $_[0]";
	@schema_tpl = <SCHEMA>;
	close SCHEMA;
	chop @schema_tpl;
}else{
	my $result = $dbi->select(
		table => $src_table,
	);
	@schema_tpl = @{$result->header};
};
};

sub Import(){
if($file_handle){
	my @source_file = <$file_handle>;
	my %counter = (update => 0, insert => 0, duplicates => 0, total => 0); #counter for actions
	#drop column captions
	my $schema_upload = shift @source_file;
	chop $schema_upload;
	open (WFILE,"> upload/source.csv") || die "Can't open source file for writing";
	foreach my $key(@source_file){
		print WFILE "$key"};
	close WFILE;
	foreach my $key(@schema){
		&GetSchema($key);
		my $schema_tpl = join("\t",@schema_tpl);
		if ($schema_tpl eq $schema_upload){
			my %duplicates = ();
			$src_table = $key;
		    $src_table=~s/schema\///;
			print p("Schema is defined. Source table: [$src_table]");
			print p('Checking for duplicates: ON') if $duplicates;
			print p('Refresh dates: ON') if $lastmod;
			open(RFILE,"< upload/source.csv") || die "Can't open source file for reading";
			while(<RFILE>){
				chop $_;
				chop $_ if $lb;
				my @import_data = split("\t",$_);
				my $data_structure = {};
				my $n=0;
				foreach my $key(@schema_tpl){
					$data_structure->{$key} = $import_data[$n];
					$n++
				};
				$data_structure->{'lastmod'} = \"NOW()" if $lastmod;
				my $id = $data_structure->{'id'} || 0;
				$duplicates{$data_structure->{'url'}}++ if $duplicates;
				if($duplicates{$data_structure->{'url'}} > 1){
					$counter{'duplicates'}++;
				}else{
					if($id != 0){
						$dbi->update(
							$data_structure,
							table => $src_table,
							where => {id => $id},
						);
						$counter{'update'}++;
					}else{
						$dbi->insert(
							$data_structure,  
	        		        table => $src_table,
						);
						$counter{'insert'}++;
					};
				};
				$counter{'total'}++;
			};
			close RFILE;
			foreach (keys %duplicates){
				print p("[d] $_ = $duplicates{$_}") if $duplicates{$_} > 1;
			};
		};
	};	
	print p('Statistics:');
	foreach (keys %counter){
		print "$_: $counter{$_}<br />";
	}
}};

sub Export(){
&GetSchema($export);
print join("\t",@schema_tpl);
print "\n";
my $result = $dbi->select(
	table => $src_table,
	column => [@schema_tpl]
);
while(my $row = $result->fetch_hash){
	foreach my $key (@schema_tpl){
		print $row->{$key};
		print "\t";
	};
	print "\n"
};
};
