#!/usr/bin/perl -w

#
#117.78.7.65,103.31.203.85
# delete from items_for_trans where 1 =1 
# update  `t_application`  set `t_application_lock_user` =0, `t_application_lock_datetime`='0000-00-00 00:00:00'  WHERE `t_application_lock_user` = 99
#
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
use Speed::Item;
use Speed::App;
use Speed::TransApp;
use TryCatch;
 use Data::Dumper;
 
our $MODE = 'test';
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


sub get_app_by_id{
    my($dbh,$app_id) = @_;
    
    my $app = Speed::App->new($dbh);
    my $item = $app->find($app_id);
}

sub get_apps{
    my($dbh,$num) = @_;
    
    my $app = Speed::App->new($dbh);
    my $rows = $app->get_new_apps($num); 
    if(!%$rows){
	   return 0;	
	}
	
	my $items = {};
	
	
	foreach my $k (sort keys %$rows){   
      $items->{$k} = add_app_for_trans($dbh, $rows->{$k},"new");   	
	}
	
	return $items;
}

sub add_app_for_trans{
	 my($dbh,$app,$act) = @_;
	 
	 my $item_t = {};
	 
	 my $it = Speed::Item->new($dbh);
	 my $item_app_id = $app->{t_application_id};
     my $item =  unserialize($app->{t_application_data});
       
     $item_t->{created} = $app->{t_application_rdatetime};
     $item_t->{modified} = $app->{t_application_udatetime};
     my $title = $item->{t_application_name};
     $item_t->{title} = $title;
     my $desc = $item->{t_application_description};
     $item_t->{desc}= $desc;
      
      #get cagegory
      
     $item_t->{cat}= $it->get_item_category($item->{t_application_m_category_id}->[0]);
     $item_t->{colors}=$item->{m_color_name};   
     $item_t->{colors_pic}=$item->{m_color_picture};
      
      #get images
     $item_t->{images}= $it->get_item_images($item_app_id); 
     $item_t->{property}= $it->get_item_property($item->{t_application_property});
     if($item->{t_application_material1}){
		  $item_t->{material}->{$it->get_item_material($item->{t_application_material1})}= $item->{t_application_material_percent1};
	 }
	 if($item->{t_application_material2}){
		  $item_t->{material}->{$it->get_item_material($item->{t_application_material2})}= $item->{t_application_material_percent2};
	 }
	 if($item->{t_application_material3}){
		  $item_t->{material}->{$it->get_item_material($item->{t_application_material3})}= $item->{t_application_material_percent3};
	 }
     
     my @metas = (); 
     foreach my $k (keys %{$item->{m_meta}}){
		    push(@metas, $it->get_item_metas($k,$item->{m_meta}->{$k}));
	 }
	  
	 $item_t->{metas} = [@metas];
	  
	  my @size = ();
	  for my $i (0..$#{$item->{t_application_size_name}->{1}}){
		  my $name_id = $item->{t_application_size_name}->{1}->[$i];
		  my $unit_id = $item->{t_application_size_unit}->{1}->[$i];
		  
		  if($name_id <= 0){
			  next;
		  }
		  
		  my $name = $it->get_item_sizes_name($name_id);
		  my $unit = $it->get_item_sizes_unit($unit_id);
		  my $guige = {}; 
		  for my $k (keys %{$item->{t_application_size_title}}){
			  if(!$item->{t_application_size_title}->{$k}){
				next;  
			  }
			 $guige->{$item->{t_application_size_title}->{$k}} =  $item->{t_application_size_value}->{$k}[$i]
		  }
		 push(@size,{name=>$name,unit=>$unit,guige=>$guige});
	  }
	  
	   $item_t->{size} = \@size;
	   $item_t->{act} = $act;
	   $item_t->{priority} = str2time($app->{t_application_udatetime});
	   
	   my $app = Speed::App->new($dbh);
	   $app->lock_app($item_app_id);
	   my $t_app = Speed::TransApp->new(get_db('stata_db'));
	   $t_app->add({app_id => $item_app_id, title => $title, desc=>$desc,item_txt=>$item_t,act=>$act});
	   
	   return $item_t; 
}



sub post_items{
	my($id,$title,$mark, $act) = @_;
	my $res = {};
	foreach my $i (0..$#$id){ 
		if( !$title->[$i] ||  !$mark->[$i]){
			$res->{$id->[$i]} = {err=>100,msg=>'title/mark为空'};
		    next;	
		}
		eval {
	  	translate_item({app_id=>$id->[$i],title_jp=>$title->[$i], mark_jp=>$mark->[$i], act=>$act->[$i]});
	    };
	    if($@){
			$res->{$id->[$i]} = {err=>100,msg=>'内部错误，接受失败'};			
		}else{
			$res->{$id->[$i]} = {err=>200,msg=>'成功接受'};			
		}
	  	
	}
    print to_json({res=>$res});
	exit();
}

sub translate_item{
   	my $item = shift;
   	my $app_id = $item->{app_id};
   
   	my $now = time;	
   	my $dbh = get_db('stata_db');
   	my $title_jp = $dbh->quote($item->{title_jp});
   	my $mark_jp = $dbh->quote($item->{mark_jp});
   	my $statu = $item->{act} == 'update' ? 'k' : 'n';
   	my $ss = "UPDATE items_for_trans SET name_jp= $title_jp, marketing_txt=$mark_jp, status='y', translated=$now WHERE app_id= $app_id ";
   	$dbh->do($ss);
}

sub recheck_app_item{
   my $app_id = shift;
   
   my $app_t = Speed::TransApp->new(get_db('stata_db'));
   
   if($app_t->exist_app($app_id)){
	   $app_t->recheck($app_id);
   }else{
	  my $dbh =get_db('main_db'); 
	  my $app = Speed::App->new($dbh);
	  my $row = $app->find($app_id);
	  add_app_for_trans($dbh,$row,"update");
   }
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
   print to_json({err=>500,msg=>"内部错误！"});
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

my $host = $cgi->remote_host();

if(!allow_remote($MODE, $host)){
		_exit_for_request("YOU ARE NOT AUTHORIZED！ WHO IS $host?");
}

my $act = $cgi->param("a");
#my $token = $cgi->param("s_t");
#my $username= $cgi->param("m_c");
#my $password = $cgi->param("p_d");

my $db_conf = get_db_conf();
   
$wrap_db = Speed::WrapDB->new($db_conf->{host}, $db_conf->{user},$db_conf->{pass} );


if($act eq 'recheck'){
	recheck_app_item($cgi->param("app_id"));
	my $res = {"err"=>200};
	print to_json($res);
	exit;
}elsif($act eq 'get'){
     my $num =  $cgi->param("num") ? $cgi->param("num") : 5;
	 my $dbh = get_db('stata_db');	
	 my $items = {};
	 
	 $dbh->{AutoCommit} = 0;  
     $dbh->{RaiseError} = 1;
     try{
	    my $t_app = Speed::TransApp->new($dbh);
	    $items = $t_app->get_rechecked_app($num);  
	    $dbh->commit;
	 }catch($err){
	   eval { $dbh->rollback };
       _log_handling_err($err);
     }
     
     if(!$items){
	  $dbh = get_db('main_db');
	  $dbh->{AutoCommit} = 0;  
      $dbh->{RaiseError} = 1;
      try{
		 $items = get_apps($dbh, $num);
		 $dbh->commit; 
	  }catch($err){
		 eval { $dbh->rollback };
         _log_handling_err($err); 
	  }
     }	
     
     my $res;
     if($items){
		$res = {err=>200, items=>$items};
	 }else{
	    $res = {err=>202, items=>{},msg=>"no more items"};
	 }
	 
	 print to_json($res);
	 exit;
}elsif($act eq 'do' or $act eq 'update'){
	my @id = $cgi->param('id');
	my @title = $cgi->param('title');
	my @mark = $cgi->param('mark');
	my @act  = $cgi->param('act');
	post_items(\@id,\@title,\@mark, \@act);
}elsif($act eq 'login'){
	#login($token, $username,$password,$host);
}else{
    _exit_from_err("WHAT IS YOU WANT TO DO?");	
}


 

