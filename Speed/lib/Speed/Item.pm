package Speed::Item;

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


sub get_item_category{
	my ($self,$cat_id) = @_;  

	my $row = $self->{_dbh}->selectrow_arrayref("SELECT m_category_name_ch  FROM m_category WHERE m_category_id = $cat_id ");
	return $row->[0];
}

sub get_item_colors{
	my ($self,$item_id) = @_;  
	
	my $row = $self->{_dbh}->selectall_hashref("SELECT m_color_name,m_color_picture FROM m_color WHERE m_color_m_item_id = $item_id");
	return $row;
}

sub get_item_images{
	my ($self,$item_app_id) = @_;  

	my $rows = $self->{_dbh}->selectall_arrayref("select t_application_img_m_space_image_id 	from t_application_img 	left join	m_space_image 	on	t_application_img.t_application_img_m_space_image_id = m_space_image_id and m_space_image_status = 1 where 	t_application_img_t_application_id = $item_app_id order by t_application_img_order asc, t_application_img_id asc");
	my @ids = ();
	foreach my $item (@$rows){
		push(@ids, $item->[0]);
	} 
	
	my $param_string = "callback=trans";

    my $p_id =uri_escape("ids[]");
    foreach my $id (@ids){	
      $param_string .="&$p_id=$id";	
    }

   my $request = HTTP::Request->new(GET => 'http://xiangce.speed-trade.com.cn/gallerys/showPageImages.json?' . $param_string);
   my $ua = LWP::UserAgent->new;
   my $response = $ua->request($request);


  if (!$response->is_success()) {
     die($response->status_line(), "\n");
  }


  my @data = $response->content() =~ /trans\((.*)\)/;

  return decode_json $data[0];
}
sub get_item_property{
	my ($self,$property_en) = @_; 
	
	my $row = $self->{_dbh}->selectrow_arrayref("SELECT m_property_name_ch FROM m_property WHERE m_property_name_en = '$property_en' ");
	return $row->[0] ? $row->[0] : "";
}
sub get_item_material{
	my ($self,$id) = @_;

	my $row = $self->{_dbh}->selectrow_arrayref("SELECT m_material_name_ch FROM m_material WHERE m_material_id = $id");
	return $row->[0] ? $row->[0] : "";
}
sub get_item_metas{
	my ($self,$mid, $vid) = @_; 
	
	my $row = $self->{_dbh}->selectrow_arrayref("SELECT m_meta_name_ch FROM  m_meta  where m_meta_id = $mid ");	
	my $meta_name = $row->[0] ? $row->[0] : "";
	
	my $meta_value = "";
	if($vid && $vid=~/\d+/){
	   my  $row = $self->{_dbh}->selectrow_arrayref("SELECT m_meta_value_ch FROM  m_meta_value where   m_meta_value_id = $vid");	
	   $meta_value = $row->[0] ? $row->[0] : "";
	}	
	
	return [$meta_name,$meta_value];
}

sub get_item_sizes_name{
	my ($self,$id) = @_;
	
	my $row = $self->{_dbh}->selectrow_arrayref("SELECT m_spec_name_ch FROM m_spec WHERE m_spec_id = $id");
	
	return $row->[0] ? $row->[0] : "";
}
sub get_item_sizes_unit{
	my ($self,$id) = @_;
	
	my $row = $self->{_dbh}->selectrow_arrayref("SELECT m_unit_name_ch FROM m_unit WHERE m_unit_id = $id");
	
	return $row->[0] ? $row->[0] : "";
}

1; # Magic true value required at end of module
__END__

=head1 NAME

Speed::Item - [One line description of module's purpose here]


=head1 VERSION

This document describes Speed::Item version 0.0.1


=head1 SYNOPSIS

    use Speed::Item;

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
  
Speed::Item requires no configuration files or environment variables.


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
C<bug-speed-item@rt.cpan.org>, or through the web interface at
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
