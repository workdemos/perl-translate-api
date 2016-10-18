package Speed::Auth;

use warnings;
use strict;
use Carp;

# Other recommended modules (uncomment to use):
#  use IO::Prompt;
#  use Perl6::Export;
#  use Perl6::Slurp;
#  use Perl6::Say;


# Module implementation here

use DBI;
use Cache::SharedMemoryCache;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Session::Token;
use JSON;

BEGIN {
	require Exporter;
	
		
	our @ISA = qw(Exporter);
	
	our @EXPORT = qw(set_db_handler authorize_api_user validate_token_from_cache allow_remote send_auth_token);
	our @EXPORT_OK = qw();
}

my $dbh;

sub set_db_handler{
   $dbh = shift;
   return 1;	
}

my  $get_db_handler = sub {
  if(!$dbh){
	die "dbh is not handler";  
  }
  return $dbh;
};

sub authorize_api_user{	
  my($username,$password,$host) = @_;
  my $dbh = $get_db_handler->('stata_db'); 
  $password = md5_hex($password);
  my $username_quote = $dbh->quote($username);
  
  my $row = $dbh->do("SELECT * FROM api_users WHERE username =$username_quote and password = '$password'   and status=1 limit 1");
  $dbh->disconnect;
  if($row == 1){
	my $token = get_user_token();
	identified_user($username,$token,$host);
	return [200,$token];  
  }
  return [201,''];
}

sub identified_user{
	my($username,$token,$host) = @_;
	my %cache_options = ( 'namespace' => 'speed-trans','default_expires_in' => 1000 );

  my $shared_memory_cache = new Cache::SharedMemoryCache( \%cache_options ) or croak( "Couldn't instantiate SharedMemoryCache" );
   if(!$shared_memory_cache->get($token)){
	  $shared_memory_cache->remove($token);
   }
   $shared_memory_cache->set($token, {"username"=>$username,"host"=>$host},"15 minutes");   
}

sub validate_user_token{
	 my($username,$token,$host) = @_;
	 my $dbh = $get_db_handler->('stata_db'); 
     my $sth = $dbh->prepare("SELECT * FROM api_users WHERE username ='$username' and token = '$token' and host='$host'  and status=1");
     $sth->execute() or die $sth->errstr;
     my $row = $sth->fetchrow_hashref();
     if(!$row->{id}){
		 return 402;
	 }
	 if(time > $row->{accessed} + 15*60 ){
	     return 401;	 
	 }
	 
	 $dbh->disconnect;
	 return 200;
}

sub validate_token_from_cache{
	my($username,$token,$host) = @_;
	my %cache_options = ( 'namespace' => 'speed-trans', 'default_expires_in' => 1000 );

  my $shared_memory_cache = new Cache::SharedMemoryCache( \%cache_options ) or croak( "Couldn't instantiate SharedMemoryCache" );
  my $data = $shared_memory_cache->get($token);
  if(!$data){
	   return 402;
  }
 
  if($data->{username} eq $username){	    
	   return 200;  
  }
  return 403;
}

sub get_user_token{
	return Session::Token->new(length => 15)->get;
}

sub send_auth_token{
   	my($statu_code,$token) = @_;
   	my $msg = "";
   	if($statu_code == 200){	 
	        $msg="授权通过";
	}elsif($statu_code == 201){
		$msg="用户名/密码错误";
	}elsif($statu_code == 401){
		$msg="登陆过期";
	}elsif($statu_code == 402){
	     $msg="Token错误";
    }elsif($statu_code == 403){
	     $msg="Token错误";
    }else{
		$msg="未知错误";
	}
	
	my $res = {err=>$statu_code,msg=>$msg};
	if(defined $token){
	  $res->{token} = $token;	
	}
	print to_json($res);	
	exit;
}

sub allow_remote{
  my($mode,$remote) = @_;
  my $hosts_for_product = {"127.0.0.1"=>1 ,"61.145.116.65"=>1,"203.195.157.23"=>1};
  my $host_for_test = {"127.0.0.1"=>1,"192.168.1.189" => 1,"219.136.24.234"=>1,"203.195.157.23"=>1,"219.136.140.29"=>1};
  
  my $hosts = $mode eq "product" ? $hosts_for_product : $host_for_test;
  
  return $hosts->{$remote} ? 1 : 0;
}

END {}


1; # Magic true value required at end of module
__END__

=head1 NAME

Speed::Auth - [One line description of module's purpose here]


=head1 VERSION

This document describes Speed::Auth version 0.0.1


=head1 SYNOPSIS

    use Speed::Auth;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
Speed::Auth requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-speed-auth@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

maxkerrer  C<< <maxkerrer@live.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2014, maxkerrer C<< <maxkerrer@live.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
