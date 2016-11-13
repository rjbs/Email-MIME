use strict;
use warnings;
package Email::MIME::Header;
# ABSTRACT: the header of a MIME message

use parent 'Email::Simple::Header';

use Email::MIME::Encode;
use Encode 1.9801;

=head1 DESCRIPTION

This object behaves like a standard Email::Simple header, with the following
changes:

=for :list
* the C<header> method automatically decodes encoded headers if possible
* the C<header_raw> method returns the raw header; (read only for now)
* stringification uses C<header_raw> rather than C<header>

Note that C<header_set> does not do encoding for you, and expects an
encoded header.  Thus, C<header_set> round-trips with C<header_raw>,
not C<header>!  Be sure to properly encode your headers with
C<Encode::encode('MIME-Header', $value)> before passing them to
C<header_set>.  And be sure to use minimal version 2.83 of Encode
module due to L<bugs in MIME-Header|Encode::MIME::Header/BUGS>.

Alternately, if you have Unicode (character) strings to set in headers, use the
C<header_str_set> method.

=cut

sub header_str {
  my $self  = shift;
  my $wanta = wantarray;

  return unless defined $wanta; # ??

  my @header = $wanta ? $self->header_raw(@_)
                      : scalar $self->header_raw(@_);

  foreach my $header (@header) {
    next unless defined $header;
    next unless $header =~ /=\?/;

    _maybe_decode(\$header);
  }
  return $wanta ? @header : $header[0];
}

sub header {
  my $self = shift;
  return $self->header_str(@_);
}

sub header_str_set {
  my ($self, $name, @vals) = @_;

  my @values = map {
    Email::MIME::Encode::maybe_mime_encode_header($name, $_, 'UTF-8')
  } @vals;

  $self->header_set($name => @values);
}

sub header_str_pairs {
  my ($self) = @_;

  my @pairs = $self->header_pairs;
  for (grep { $_ % 2 } (1 .. $#pairs)) {
    _maybe_decode(\$pairs[$_]);
  }

  return @pairs;
}

sub _maybe_decode {
  my ($str_ref) = @_;

  # The eval is to cope with unknown encodings, like Latin-62, or other
  # nonsense that gets put in there by spammers and weirdos
  # -- rjbs, 2014-12-04
  local $@;
  my $new;
  $$str_ref = $new
    if eval { $new = Encode::decode("MIME-Header", $$str_ref); 1 };
  return;
}

1;
