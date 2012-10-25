#!/usr/bin/perl -w

use strict;
use warnings;
use CGI qw/:standard/;
use DBIx::Custom;
use utf8;
use v5.14;

open (DBCONF,"< app.conf") || die "Error open dbconfig file";
my @appconf=<DBCONF>;
close DBCONF;
chomp @appconf;

my $dbi = DBIx::Custom->connect(
            dsn => $appconf[0],
            user => $appconf[1],
            password => $appconf[2],
            option => {mysql_enable_utf8=>1}
);

$dbi->do('SET NAMES utf8');

my @schema = <schema/*>;
my @schema_tpl = '';
open (SCHEMA,"< schema/products") || die "can't load schema file";
@schema_tpl = <SCHEMA>;
close SCHEMA;
chop @schema_tpl;
#say @schema_tpl;
#print @schema_tpl;
#print '1';

#my $colschema = {'url','title'};
#$dbi->insert(
#	$colschema,
#	table => 'products',
#);
#exit;

#get cgi variables
my $file_handle = upload('source') ||undef;
my $export = param('export') || undef;
#select line break characters
my $lb = param('linebreak') || undef;

if($export){
	$export=~s/schema\///;
	print header(
		-type => 'text/csv',
		-charset => 'utf-8',
		-attachment => $export.'.csv',
	);
	&Export;
}else{
	print header(
		-charset => 'utf-8',
		-type => 'text/html',
	);
    print start_html;
    print start_form(-action => 'upload.pl',-method => 'post');
    print filefield(-name => 'source');
    print checkbox(-name => 'linebreak',-value => 1, -label => 'OS Windows');
    print submit(-value => 'Import');
    print end_form;
    print start_form(-action => 'upload.pl', -method => 'post');
    print popup_menu(-name => 'export', -values => [@schema]);
    print submit(-value => 'Export');
    print end_form;
    &Upload;
    print p('<a href="/">Open domain</a>');
    print end_html;
};

sub Upload(){
	if($file_handle){
		my @source_file = <$file_handle>;
		#drop column captions
		shift @source_file;
		open (WFILE,"> upload/source.csv") || die "Can't open source file for writing";
		foreach my $key(@source_file){
			print WFILE "$key";
		}
		close WFILE;
		
		open(RFILE,"< upload/source.csv") || die "Can't open source file for reading";
			my %counter = ('update' => 0, 'insert' => 0); #Counter for actions
			while(<RFILE>){
				chop $_;
				chop $_ if $lb;
				#my ($id,$url,$title,$description,$settings,$features,$image,$price,$instore,$metadescription,$caturl,$vk_album,$popular) = split(';',$_);
				my @import_data = split(';',$_);
				my $data_structure = {};
				my $n=0;
				foreach my $key(@schema_tpl){
					$data_structure->{$key}= $import_data[$n];
					$n++;
				}
				my $result = $dbi->select(
					table => 'products',
					column => 'id',
					where => {'id' => $data_structure->{'id'}});
				my $id = $result->value || 0;
				if ($id){
					$dbi->update(
						$data_structure,
						table => 'products',
						where => {id => $id});
					$counter{'update'}++;
				}else{
					$dbi->insert(
						$data_structure,  
		                table => 'products',
					);
					$counter{'insert'}++;
				};
			};
		print p("Statistics: update=$counter{'update'}, insert=$counter{'insert'}");
		close RFILE;
	}
}#UploadStore

sub Export(){
	print join(';',@schema_tpl);
	print "\n";
	my $products = $dbi->select(
			table => 'products',
			column => [@schema_tpl],
		);

	while(my $row = $products->fetch_hash){
		foreach my $key (@schema_tpl){
			print $row->{$key};
			print ';';
		}
		print "\n";
	};
}#ExportStore
