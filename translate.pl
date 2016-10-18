#!/usr/bin/perl -w

use JSON;
use DBI;
use Cache::SharedMemoryCache;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Session::Token;
use PHP::Serialization qw(serialize unserialize);
use strict;
use LWP::UserAgent qw( );
use URI::Escape    qw( uri_escape );
use HTTP::Request;
use POSIX qw(strftime);
use HTTP::Request::Common;
use Log::Log4perl;
use TryCatch;
#use UNIVERSAL::isa;

our $MODE = 'product';
our $HOST = 'localhost';
our $DB_USER = 'speedtrade';
our $DB_PASS = 'husy$sH8&sy';

our $DB_SPEED = "speedTrade";
our $DB_STATA = "speedSTATAS";

our $API_TRANS ="https://admin.speed-trade.com.cn/api/remote_act?a=translate_item_app";

sub get_db_handler{
   my $database = shift;
   my $dbh = DBI->connect("DBI:mysql:$database;host=$HOST",$DB_USER,$DB_PASS,{
	        PrintError => 1,
	        RaiseError => 1
	     }) or die "can not connect to db: $DBI::errstr";                                                    
   $dbh->do("SET NAMES utf8");	
   return $dbh;
}

sub prepare_items{
	
    my $dbh = get_db_handler($DB_STATA); 
    my $rows = $dbh->selectall_hashref("SELECT idsss,app_id,name_jp,marketing_txt,revision from items_for_trans WHERE status='y' order by translated limit 3 ","app_id");
    return $rows;
}

sub post_translated{
   	my $items = shift;
   	
   	my @ids = (); 	
   	my @title_jps = ();
   	my @marks = ();
	my @revisions = ();
	
	for my $k (sort keys %$items){ 
		push @ids, $items->{$k}->{app_id};
		push @title_jps, $items->{$k}->{name_jp};
		push @marks, $items->{$k}->{marketing_txt};
		push @revisions, $items->{$k}->{revision};
	}
		
	if(!@ids){
	  exit;
	}
    my $ua = LWP::UserAgent->new;

    my $response = $ua->request(POST $API_TRANS, 
                    [
                       "a" => "translate_item_app",
                       "ids[]" => [@ids],
                       "title_jps[]" => [@title_jps],
                       "marks[]" => [@marks],
                       "revisions[]" => [@revisions]
                    ]    
    );
     
    if (!$response->is_success()) {
      die($response->status_line(), "\n");
    }

  return decode_json $response->content();
}

sub analyze_act_result{
	my $res = shift;
	
	if($res->{err} !=200){
	 print "返回数据不能处理";
	 return 0;	
	}
	
	my $items = $res->{items};
	for my $k (sort keys %$items){
		
		if($items->{$k}->{err} == 200){
			finish_app_translate($k);
		}else{
			err_app_translate($k,$items->{$k}->{err});
		}	 
	}
}

sub finish_app_translate{
	my $app_id = shift;	
    my $dbh = get_db_handler($DB_STATA); 
    my $now = time;	
    
    $dbh->do("UPDATE  items_for_trans SET  	status='f',finished=$now where app_id=$app_id");    
}

sub err_app_translate{
	my($app_id, $err_code) = @_;
	my $dbh = get_db_handler($DB_STATA); 
    
    $dbh->do("UPDATE  items_for_trans SET  	status='e',err_code=$err_code where app_id=$app_id");
}

my  $items;

try{
 $items = prepare_items();
}catch($err){
   Log::Log4perl->init("log.conf");
   my $log = Log::Log4perl->get_logger();
   $log->error($err);
   exit;	
}
exit if !$items;

my $response = post_translated($items);
analyze_act_result($response);
exit;
