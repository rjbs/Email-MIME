use strict;
use warnings;
package Email::MIME::Header;
use base 'Email::Simple::Header';

our $VERSION = '1.902';

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

Note that C<header_set> does not do encoding for you, and expects an
encoded header.  Thus, C<header_set> round-trips with C<header_raw>,
not C<header>!  Be sure to properly encode your headers with
C<Encode::encode('MIME-Header', $value)> before passing them to
C<header_set>.

Alternately, if you have Unicode (character) strings to set in headers, use the
C<header_str_set> method.

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

sub header_str_set {
  my ($self, $name, @vals) = @_;

  my @values = map { Encode::encode('MIME-Q', $_, 1) } @vals;

  $self->header_set($name => @values);
}

sub _header_decode_str {
  my ($self, $str) = @_;
  my $new_str;
  $new_str = $str
    unless eval { $new_str = Encode::decode("MIME-Header", $str); 1 };
  return $new_str;
}

=head1 COPYRIGHT

This software is copyright (c) 2004 by Simon Cozens.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
