package Speed::Message;

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
use LWP::UserAgent qw( );
use URI::Escape    qw( uri_escape );
use HTTP::Request;
use POSIX qw(strftime);
use JSON;

sub new {
   my $class = shift;
   my $self = {
	    _dbh => shift
	    
	 };
   bless $self, $class;
   return $self;
}

sub get_new_messages{
	my ($self,$num) = @_;  

	my $rows = $self->{_dbh}->selectall_hashref("select * from t_support_maker where  t_trans_status = 'will' and  t_maker_support_maker_trashbox_flag =0 and t_support_maker_type = 'msg' and t_maker_support_maker_delete_flag = 0 limit $num","t_support_maker_id");
	
	return $self->format_message($rows);
}

sub add{
	my($self, $mess_id, $header, $body) = @_;
      
   	my $now = time;	
  
    $header = $self->{_dbh}->quote($header);
   	$body = $self->{_dbh}->quote($body);

   	$self->{_dbh}->do("UPDATE t_support_maker SET t_title=$header, t_body=$body,  t_trans_status = 'done' WHERE  t_support_maker_id = $mess_id ");
}

sub update_status{
  my($self,$mess_id,$status) = @_;
  
  $self->{_dbh}->do("UPDATE t_support_maker SET  t_trans_status = '$status' WHERE  t_support_maker_id = $mess_id ");	
}

sub get_history{
  my($self,	$maker_id,$customer_id,$cur_mess_id,$num) = @_;
  my $rows = $self->{_dbh}->selectall_hashref("select *  from t_support_maker where t_support_maker_m_maker_id LIKE '%$maker_id%' AND t_support_maker_m_customer_id LIKE '%$customer_id%' and t_support_maker_id <$cur_mess_id and  t_maker_support_maker_trashbox_flag =0 and t_support_maker_type = 'msg' and t_maker_support_maker_delete_flag = 0  AND  t_trans_status = 'done' ORDER BY t_support_maker_id DESC LIMIT $num","t_support_maker_id");
  
  return $self->format_message($rows);
}

sub format_message{
  my($self,$rows) = @_;
 
  my $mess = {};
  
  foreach my $k (sort keys %$rows){
		my $mess_id = $rows->{$k}->{t_support_maker_id};	    
	    $mess->{$mess_id}->{created} = $rows->{$k}->{t_support_maker_rdatetime};
	    
	    my $send = $rows->{$k}->{t_support_maker_to} eq 'user' ? 'makerToUser' : 'userToMaker';
	    $mess->{$mess_id}->{send_method} =  $send;
	    if($send eq 'makerToUser'){
			$mess->{$mess_id}->{sender} =  $rows->{$k}->{t_support_maker_m_maker_id};
	        $mess->{$mess_id}->{reciver} =  $rows->{$k}->{t_support_maker_m_customer_id};	
	        $mess->{$mess_id}->{header} = 	$rows->{$k}->{t_support_maker_title};
	        $mess->{$mess_id}->{body} = 	$rows->{$k}->{t_support_maker_body};       
		}else{
			$mess->{$mess_id}->{sender} =  $rows->{$k}->{t_support_maker_m_customer_id};
	        $mess->{$mess_id}->{reciver} =  $rows->{$k}->{t_support_maker_m_maker_id};
	        $mess->{$mess_id}->{header} = 	$rows->{$k}->{t_title} ? $rows->{$k}->{t_title} : $rows->{$k}->{t_support_maker_title};
	        $mess->{$mess_id}->{body} = 	$rows->{$k}->{t_body}  ? $rows->{$k}->{t_body}  : $rows->{$k}->{t_support_maker_body};
		}	   
  }
  
  return $mess;
}

1; # Magic true value required at end of module
__END__

=head1 NAME

Speed::Message - [One line description of module's purpose here]


=head1 VERSION

This document describes Speed::Message version 0.0.1


=head1 SYNOPSIS

    use Speed::Message;

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
  
Speed::Message requires no configuration files or environment variables.


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
C<bug-speed-message@rt.cpan.org>, or through the web interface at
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
