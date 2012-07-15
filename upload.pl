#!/usr/bin/perl -w
#===============================================================================
#
#         FILE:  upload.pl
#
#        USAGE:  ./upload.pl  
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
#      CREATED:  06/27/2012 11:51:42 AM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use CGI qw/:standard/;
use DBIx::Custom;
use utf8;

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

my $file_handle = upload('source') ||undef;
my $export = param('export') || undef;
my $lb = param('linebreak') || undef; #Select line break characters

if($export){
	print header(
		-type => 'text/csv',
		-charset => 'utf-8',
		-attachment => 'exportstore.csv',
	);
	&ExportStore;
}else{
	print header(
		-charset => 'utf-8',
		-type => 'text/html',
	);
    print start_html;
    print start_form(-action => 'upload.pl',-method => 'post');
    print filefield(-name => 'source');
    print checkbox(-name => 'linebreak',-value => 1, -label => 'OS Windows');
    print submit;
    print end_form;
	&UploadStore;
    print p('<a href="?export=yes" target=_blank>Export store</a>');
    print end_html;
};

sub UploadStore(){
	if($file_handle){
		my @source_file = <$file_handle>;
		shift @source_file;
		open (WFILE,"> upload/store.csv") || die "Can't open source file for writing";
		foreach my $key(@source_file){
			print WFILE "$key";
		}
		close WFILE;
		
		open(RFILE,"< upload/store.csv") || die "Can't open source file for reading";
			my %counter = ('update' => 0, 'insert' => 0); #Counter for actions
			while(<RFILE>){
				chop $_;
				chop $_ if $lb;
				my ($id,$url,$title,$description,$settings,$features,$image,$price,$instore,$anonse,$caturl) = split(';',$_);
				my $result = $dbi->select(
					table => 'product',
					column => 'id',
					where => {'url' => $url}
				);
				my $id = $result->value || 0;
				if ($id){
					$dbi->update(
						{
							url => $url,
							title => $title,
							description => $description,
							settings => $settings,
							features => $features,
							image => $image,
							price => $price,
							instore => $instore,
							anonse => $anonse,
							caturl => $caturl,
						},
						table => 'product',
						where => {id => $id}
					);
					$counter{'update'}++;
				}else{
					$dbi->insert(
						{
							url => $url,
                            title => $title,
                            description => $description,
                            settings => $settings,
                            features => $features,
                            image => $image,
                            price => $price,
                            instore => $instore,
                            anonse => $anonse,
                            caturl => $caturl,
	            	    },  
		                table => 'product',
					);
					$counter{'insert'}++;
				};
			};
		print p("Statistics: update=$counter{'update'}, insert=$counter{'insert'}");
		close RFILE;
	}
}#UploadStore

sub ExportStore(){
	my @columns = (
					'id',
                    'url',
                    'title',
                    'description',
                    'settings',
                    'features',
                    'image',
                    'price',
                    'instore',
                    'anonse',
                    'caturl',
	);
	print join(';',@columns);
	print "\n";
	my $products = $dbi->select(
			table => 'product',
			column => [@columns],
		);

	while(my $row = $products->fetch_hash){
		foreach my $key (@columns){
			print $row->{$key};
			print ';';
		}
		print "\n";
	};
}#ExportStore
