#!/usr/bin/perl -w

use strict;
use warnings;

use CGI  qw/:standard/;
use CGI::Carp qw(fatalsToBrowser);
use JSON;
use DBI;
use PHP::Serialization qw(serialize unserialize);
use POSIX qw(strftime);
use HTTP::Date;
use Log::Log4perl;
use Speed::Auth;
use Speed::WrapDB;
use Speed::Message;
use TryCatch;

our $MODE = 'dev';
our $db_product = {
	   'host' => 'localhost',
	   'user' => 'speedtrade',
	   'pass' => 'husy$sH8&sy',
	   'main_db'=> 'speedTrade',
	   'stata_db' => 'speedSTATAS'
	};
our $db_dev = {
	   'host' => '192.168.1.145',
	   'user' => 'root',
	   'pass' => '123456',
	   'main_db'=> 'speedtrade',
	   'stata_db' => 'speedSTATAS'
	};	
our $db_test = {
	   'host' => 'localhost',
	   'user' => 'speedtrade',
	   'pass' => 'husy$sH8&sy',
	   'main_db'=> 'speedTest',
	   'stata_db' => 'speedTest'
	};
		
our $wrap_db;

sub get_db_conf{
   my $db;
   
   if($MODE eq 'product'){
	   $db = $db_product; 
   }elsif($MODE eq 'dev'){
	   $db = $db_dev; 
   }elsif($MODE eq 'test'){
	   $db = $db_test; 
   }
   return $db;
}

sub get_db{
   my $db_name = shift;
   
   my $db_conf = get_db_conf();
   
   if(!$db_conf->{$db_name}){
	  _exit_from_err("$db_name is not exist!");   
   }
    	
   return $wrap_db->get_db_handler($db_conf->{$db_name});
}

sub get_messages{
	my($dbh,$num) = @_;
	
	my $mess = {};
	
	my $message = Speed::Message->new($dbh);

	return $message->get_new_messages($num);
}

sub post_messages{
	my($dbh,$ids,$headers,$bodys) = @_;
	my $res = {};
	foreach my $i (0..$#$ids){
		if( !$headers->[$i] ||  !$bodys->[$i]){
			$res->{$ids->[$i]} = {err=>402,msg=>'header/body为空'};
		    next;	
		}
		try{
	  	    translate_mess($dbh, $ids->[$i],$headers->[$i], $bodys->[$i]);
	  	    $res->{$ids->[$i]} = {err=>200,msg=>'成功接受'};	
	    }catch($err){
			_log_handling_err($err);
			$res->{$ids->[$i]} = {err=>500,msg=>'内部错误，接受失败'};	
		}			  	
	}
	
    print to_json({err=>200,mess=>$res});
	exit();
}

sub translate_mess{
	my($dbh, $mess_id, $header, $body) = @_;
    my $mess = Speed::Message->new($dbh);
    $mess->add($mess_id,$header,$body);
}

sub update_mess_status{
  my($dbh,$mess_id,$status) = @_;
  my $mess  = Speed::Message($dbh);
  $mess->update_status($mess_id, $status);
}

sub get_maker_info{
	my($dbh,$mess_id,$maker_id) = @_;
	if(!exist_message($dbh,$mess_id)){
	   _exit_for_request("站内信不存在，id: $mess_id");
	}
	
	my $rows = $dbh->selectall_arrayref("SELECT m_maker_id,m_maker_name,m_maker_sekininsha_email_support,m_maker_sekininsha_tel,m_maker_qq  FROM m_maker WHERE m_maker_id = $maker_id");
	
	if(scalar(@$rows) !=1){
		_exit_for_request("商家id不存在，id: $maker_id");
	}
	
	my $maker = $rows->[0];
	return ($maker->[0], $maker->[1], $maker->[2],$maker->[3],$maker->[4]);
	
}

sub get_buyer_info{
	my($dbh,$mess_id,$buyer_id) = @_;
	if(!exist_message($dbh,$mess_id)){
	   _exit_for_request("站内信不存在，id: $mess_id");
	}
	
	my $rows = $dbh->selectall_arrayref("SELECT m_customer_id,m_customer_account, m_customer_mail FROM m_customer WHERE m_customer_id = $buyer_id");
	
	if(scalar(@$rows) !=1){
		_exit_for_request("买家id不存在，id: $buyer_id");
	}
	
	my $buyer = $rows->[0];
	return ($buyer->[0], $buyer->[1], $buyer->[2]);
}


sub exist_message{
   my($dbh, $mess_id) = @_;
   my $rows = $dbh->selectall_arrayref("SELECT t_support_maker_id FROM t_support_maker WHERE t_support_maker_id = $mess_id");

   return scalar(@$rows) ==1 ? 1 : 0;
}

sub login{
	my ($token,$username,$password,$host ) = @_;
	set_db_handler(get_db('stata_db'));
	if( (!$token && !$username)  || (!$username && !$password) ){
	   die "can not continue";
    }
    
    if(not defined $token){
	   my $res = authorize_api_user($username, $password,$host);
	   send_auth_token($res->[0],$res->[1]);
	   exit;
    }else{
	   my $statu_code = validate_token_from_cache($username,$token,$host);
	   if($statu_code != 200){
		  send_auth_token($statu_code);
		  exit;
	   }
	}
	return 1; 
}

sub _exit_from_err{
   my $msg = shift;
   Log::Log4perl->init("log.conf");
   my $log = Log::Log4perl->get_logger();
   $log->error($msg);
   print to_json({err=>500,msg=>$msg});
   exit;	
}

sub _exit_for_request{
	my $msg = shift;
	print to_json({err=>500,msg=>$msg});
    exit;
}

sub _log_handling_err{
	my $msg = shift;
   Log::Log4perl->init("log.conf");
   my $log = Log::Log4perl->get_logger();
   $log->error($msg);
}

my $cgi = new CGI;  
print $cgi->header('application/json');

my $act = $cgi->param("a");
my $host = $cgi->remote_host();

if(!allow_remote($MODE,$host)){
		_exit_for_request("YOU ARE NOT AUTHORIZED！ WHO IS $host?");
}
	
my $db_conf = get_db_conf();
   
$wrap_db = Speed::WrapDB->new($db_conf->{host}, $db_conf->{user},$db_conf->{pass} );

my $dbh = get_db('main_db'); 
if($act eq 'recheck'){
	recheck_app_item($cgi->param("app_id"));
	my $res = {"err"=>200};
	print to_json($res);
	exit;
}elsif($act eq 'getmess'){
	 	
	 my $mess = {};
	 my $num = $cgi->param("num") ? $cgi->param("num") : 5;
	 
	 $mess = get_messages($dbh,$num);	  
    
     my $res;
     if($mess){
		$res = {err=>200, mess=>$mess};
	 }else{
	    $res = {err=>202, mess=>{},msg=>"no more messages"};	 
	 }
	 
	 print to_json($res);
	 exit;
}elsif($act eq 'getmaker'){
     my $mess_id = $cgi->param("mess");
     my $maker_id = $cgi->param("maker");
     
     if(!$mess_id || !$maker_id){
		 _exit_for_request("参数有错/不完整");
	 }
	 
	 my($maker_id,$maker_name,$maker_email,$telphone,$qq) = get_maker_info($dbh, $mess_id,$maker_id);
	 print to_json({"err"=>200,"maker"=>{"id"=>$maker_id,"telphone"=>$telphone, "name"=>$maker_name, "email"=>$maker_email,"qq"=>$qq}});
}elsif($act eq 'getbuyer'){
	 my $mess_id = $cgi->param("mess");
     my $buyer_id = $cgi->param("buyer");
     
     if(!$mess_id || !$buyer_id){
		 _exit_for_request("参数有错/不完整");
	 }
	 
	 my($buyer_id,$buyer_name,$buyer_email) = get_buyer_info($dbh, $mess_id,$buyer_id);
	 print to_json({"err"=>200,"buyer"=>{"id"=>$buyer_id, "name"=>$buyer_name, "email"=>$buyer_email}});
}elsif($act eq 'doget'){
   	my @ids = $cgi->param('id');
   	my @status = $cgi->param('s_t');   	
   	
   	
    my $message  = Speed::Message->new($dbh);
    my $res = {};
   	for(my $i=0; $i<=$#ids; $i++){
		if($status[$i] !=1){
	       $res->{$ids[$i]} = {err=>200,msg=>'已记录'};
	       next;
	    }
		
		try{
			  $message->update_status($ids[$i],"doing");
			  $res->{$ids[$i]} = {err=>200,msg=>'已记录'};	
		}catch($err){
			 _log_handling_err($err);
			 $res->{$ids[$i]} = {err=>500,msg=>'内部错误，记录失败'};		  
		}         
    }
	
	print to_json({err=>200,mess=>$res});
	
}elsif($act eq 'do' or $act eq 'update'){
	my @ids = $cgi->param('id');
	my @headers = $cgi->param('header');
	my @bodys = $cgi->param('body');
	post_messages($dbh, \@ids,\@headers,\@bodys);
}elsif($act eq 'gethistory'){
	my $maker_id =  $cgi->param('maker');
	my $customer_id =  $cgi->param('buyer');
	my $cur_mess_id = $cgi->param('id');
	
	if(!$maker_id || !$customer_id || !$cur_mess_id){
		_exit_for_request("参数不正确");
	}
	my $num = $cgi->param('num') ? $cgi->param('num') : 5;
	
	my $message = Speed::Message->new($dbh);
	my $mess = $message->get_history($maker_id,$customer_id,$cur_mess_id,$num);
	
    my $res;
    if($mess){
		$res = {err=>200, mess=>$mess};
    }else{
	    $res = {err=>202, mess=>{},msg=>"no more messages"};	 
	}
	 
	 print to_json($res);
	 exit;
}else{
    _exit_from_err("WHAT IS YOU WANT TO DO？");	
}

exit;

