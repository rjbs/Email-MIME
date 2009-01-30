use strict;
use warnings;
package Email::MIME::Header;
use base 'Email::Simple::Header';

our $VERSION = '1.863';

use Encode 1.9801;

=head1 NAME

Email::MIME::Header - the header of a MIME message

=head1 DESCRIPTION

This object behaves like a standard Email::Simple header, with the following
changes:

=over 4

=item * the C<header> method automatically decodes encoded headers if possible

=item * the C<header_raw> method returns the raw header; (read only for now)

=item * stringification uses C<header_raw> rather than C<header>

=back

=cut

sub header {
  my $self   = shift;
  my @header = $self->SUPER::header(@_);
  local $@;
  foreach my $header (@header) {
    next unless $header =~ /=\?/;
    $header = $self->_header_decode_str($header);
  }
  return wantarray ? (@header) : $header[0];
}

sub header_raw {
  Carp::croak "header_raw may not be used to set headers" if @_ > 2;
  my ($self, $header) = @_;
  return $self->SUPER::header($header);
}

sub _header_decode_str {
  my ($self, $str) = @_;
  my $new_str;
  $new_str = $str
    unless eval { $new_str = Encode::decode("MIME-Header", $str); 1 };
  return $new_str;
}

=head1 COPYRIGHT

Copyright (C) 2004, Simon Cozens.  Email-MIME is free software.  You may
distribute this module under the terms of the Artistic or GPL licenses.

=cut

1;
