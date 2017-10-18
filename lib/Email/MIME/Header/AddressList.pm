# Copyright (c) 2016-2017 by Pali <pali@cpan.org>

package Email::MIME::Header::AddressList;

use strict;
use warnings;

use Carp ();
use Email::Address::XS;
use Email::MIME::Encode;
use Net::IDN::Encode;

=encoding utf8

=head1 NAME

Email::MIME::Header::AddressList - MIME support for list of Email::Address::XS objects

=head1 SYNOPSIS

  use utf8;
  use Email::Address::XS;
  use Email::MIME::Header::AddressList;

  my $address1 = Email::Address::XS->new('Name1' => 'address1@host.com');
  my $address2 = Email::Address::XS->new("Name2 \N{U+263A}" => 'address2@host.com');
  my $mime_address = Email::Address::XS->new('=?UTF-8?B?TmFtZTIg4pi6?=' => 'address2@host.com');

  my $list1 = Email::MIME::Header::AddressList->new($address1, $address2);

  $list1->append_groups('undisclosed-recipients' => []);

  $list1->first_address();
  # returns $address1

  $list1->groups();
  # returns (undef, [ $address1, $address2 ], 'undisclosed-recipients', [])

  $list1->as_string();
  # returns 'Name1 <address1@host.com>, "Name2 ☺" <address2@host.com>, undisclosed-recipients:;'

  $list1->as_mime_string();
  # returns 'Name1 <address1@host.com>, =?UTF-8?B?TmFtZTIg4pi6?= <address2@host.com>, undisclosed-recipients:;'

  my $list2 = Email::MIME::Header::AddressList->new_groups(Group => [ $address1, $address2 ]);

  $list2->append_addresses($address2);

  $list2->addresses();
  # returns ($address2, $address1, $address2)

  $list2->groups();
  # returns (undef, [ $address2 ], 'Group', [ $address1, $address2 ])

  my $list3 = Email::MIME::Header::AddressList->new_mime_groups('=?UTF-8?B?4pi6?=' => [ $mime_address ]);
  $list3->as_string();
  # returns '☺: "Name2 ☺" <address2@host.com>;'

  my $list4 = Email::MIME::Header::AddressList->from_string('Name1 <address1@host.com>, "Name2 ☺" <address2@host.com>, undisclosed-recipients:;');
  my $list5 = Email::MIME::Header::AddressList->from_string('Name1 <address1@host.com>', '"Name2 ☺" <address2@host.com>', 'undisclosed-recipients:;');

  my $list6 = Email::MIME::Header::AddressList->from_mime_string('Name1 <address1@host.com>, =?UTF-8?B?TmFtZTIg4pi6?= <address2@host.com>, undisclosed-recipients:;');
  my $list7 = Email::MIME::Header::AddressList->from_mime_string('Name1 <address1@host.com>', '=?UTF-8?B?TmFtZTIg4pi6?= <address2@host.com>', 'undisclosed-recipients:;');

=head1 DESCRIPTION

This module implements object representation for the list of the
L<Email::Address::XS|Email::Address::XS> objects. It provides methods for
L<RFC 2047|https://tools.ietf.org/html/rfc2047> MIME encoding and decoding
suitable for L<RFC 2822|https://tools.ietf.org/html/rfc2822> address-list
structure.

=head2 EXPORT

None

=head2 Class Methods

=over 4

=item new_empty

Construct new empty C<Email::MIME::Header::AddressList> object.

=cut

sub new_empty {
  my ($class) = @_;
  return bless { addresses => [], groups => [] }, $class;
}

=item new

Construct new C<Email::MIME::Header::AddressList> object from list of
L<Email::Address::XS|Email::Address::XS> objects.

=cut

sub new {
  my ($class, @addresses) = @_;
  my $self = $class->new_empty();
  $self->append_addresses(@addresses);
  return $self;
}

=item new_groups

Construct new C<Email::MIME::Header::AddressList> object from named groups of
L<Email::Address::XS|Email::Address::XS> objects.

=cut

sub new_groups {
  my ($class, @groups) = @_;
  my $self = $class->new_empty();
  $self->append_groups(@groups);
  return $self;
}

=item new_mime_groups

Like L<C<new_groups>|/new_groups> but in this method group names and objects properties are
expected to be already MIME encoded, thus ASCII strings.

=cut

sub new_mime_groups {
  my ($class, @groups) = @_;
  if (scalar @groups % 2) {
    Carp::carp 'Odd number of elements in argument list';
    return;
  }
  foreach (0 .. scalar @groups / 2 - 1) {
    $groups[2 * $_] = Email::MIME::Encode::mime_decode($groups[2 * $_])
      if defined $groups[2 * $_] and $groups[2 * $_] =~ /=\?/;
    $groups[2 * $_ + 1] = [ @{$groups[2 * $_ + 1]} ];
    foreach (@{$groups[2 * $_ + 1]}) {
      next unless Email::Address::XS->is_obj($_);
      my $phrase = $_->phrase;
      my $comment = $_->comment;
      my $host = $_->host;
      my $decode_phrase = (defined $phrase and $phrase =~ /=\?/);
      my $decode_comment = (defined $comment and $comment =~ /=\?/);
      my $decode_host = (defined $host and $host =~ /xn--/);
      next unless $decode_phrase or $decode_comment or $decode_host;
      $_ = ref($_)->new(copy => $_);
      $_->phrase(Email::MIME::Encode::mime_decode($phrase))
        if $decode_phrase;
      $_->comment(Email::MIME::Encode::mime_decode($comment))
        if $decode_comment;
      $_->host(Net::IDN::Encode::domain_to_unicode($host))
        if $decode_host;
    }
  }
  return $class->new_groups(@groups);
}

=item from_string

Construct new C<Email::MIME::Header::AddressList> object from input string arguments.
Calls L<Email::Address::XS::parse_email_groups|Email::Address::XS/parse_email_groups>.

=cut

sub from_string {
  my ($class, @strings) = @_;
  return $class->new_groups(map { Email::Address::XS::parse_email_groups($_) } @strings);
}

=item from_mime_string

Like L<C<from_string>|/from_string> but input string arguments are expected to
be already MIME encoded.

=cut

sub from_mime_string {
  my ($class, @strings) = @_;
  return $class->new_mime_groups(map { Email::Address::XS::parse_email_groups($_) } @strings);
}

=back

=head2 Object Methods

=over 4

=item as_string

Returns string representation of C<Email::MIME::Header::AddressList> object.
Calls L<Email::Address::XS::format_email_groups|Email::Address::XS/format_email_groups>.

=cut

sub as_string {
  my ($self) = @_;
  return Email::Address::XS::format_email_groups($self->groups());
}

=item as_mime_string

Like L<C<as_string>|/as_string> but output string will be properly and
unambiguously MIME encoded. MIME encoding is done before calling
L<Email::Address::XS::format_email_groups|Email::Address::XS/format_email_groups>.

=cut

sub as_mime_string {
  my ($self, $arg) = @_;
  my $charset = $arg->{charset};
  my $header_name_length = $arg->{header_name_length};

  my @groups = $self->groups();
  foreach (0 .. scalar @groups / 2 - 1) {
    $groups[2 * $_] = Email::MIME::Encode::mime_encode($groups[2 * $_], $charset)
      if Email::MIME::Encode::_needs_mime_encode_addr($groups[2 * $_]);
    $groups[2 * $_ + 1] = [ @{$groups[2 * $_ + 1]} ];
    foreach (@{$groups[2 * $_ + 1]}) {
      my $phrase = $_->phrase;
      my $comment = $_->comment;
      my $host = $_->host;
      my $encode_phrase = Email::MIME::Encode::_needs_mime_encode_addr($phrase);
      my $encode_comment = Email::MIME::Encode::_needs_mime_encode_addr($comment);
      my $encode_host = (defined $host and $host =~ /\P{ASCII}/);
      next unless $encode_phrase or $encode_comment or $encode_host;
      $_ = ref($_)->new(copy => $_);
      $_->phrase(Email::MIME::Encode::mime_encode($phrase, $charset))
        if $encode_phrase;
      $_->comment(Email::MIME::Encode::mime_encode($comment, $charset))
        if $encode_comment;
      $_->host(Net::IDN::Encode::domain_to_ascii($host))
        if $encode_host;
    }
  }
  return Email::Address::XS::format_email_groups(@groups);
}

=item first_address

Returns first L<Email::Address::XS|Email::Address::XS> object.

=cut

sub first_address {
  my ($self) = @_;
  return $self->{addresses}->[0] if @{$self->{addresses}};
  my $groups = $self->{groups};
  foreach (0 .. @{$groups} / 2 - 1) {
    next unless @{$groups->[2 * $_ + 1]};
    return $groups->[2 * $_ + 1]->[0];
  }
  return undef;
}

=item addresses

Returns list of all L<Email::Address::XS|Email::Address::XS> objects.

=cut

sub addresses {
  my ($self) = @_;
  my $t = 1;
  my @addresses = @{$self->{addresses}};
  push @addresses, map { @{$_} } grep { $t ^= 1 } @{$self->{groups}};
  return @addresses;
}

=item groups

Like L<C<addresses>|/addresses> but returns objects with named groups.

=cut

sub groups {
  my ($self) = @_;
  my @groups = @{$self->{groups}};
  $groups[2 * $_ + 1] = [ @{$groups[2 * $_ + 1]} ]
    foreach 0 .. scalar @groups / 2 - 1;
  unshift @groups, undef, [ @{$self->{addresses}} ]
    if @{$self->{addresses}};
  return @groups;
}

=item append_addresses

Append L<Email::Address::XS|Email::Address::XS> objects.

=cut

sub append_addresses {
  my ($self, @addresses) = @_;
  my @valid_addresses = grep { Email::Address::XS->is_obj($_) } @addresses;
  Carp::carp 'Argument is not an Email::Address::XS object' if scalar @valid_addresses != scalar @addresses;
  push @{$self->{addresses}}, @valid_addresses;
}

=item append_groups

Like L<C<append_addresses>|/append_addresses> but arguments are pairs of name of
group and array reference of L<Email::Address::XS|Email::Address::XS> objects.

=cut

sub append_groups {
  my ($self, @groups) = @_;
  if (scalar @groups % 2) {
    Carp::carp 'Odd number of elements in argument list';
    return;
  }
  my $carp_invalid = 1;
  my @valid_groups;
  foreach (0 .. scalar @groups / 2 - 1) {
    push @valid_groups, $groups[2 * $_];
    my $addresses = $groups[2 * $_ + 1];
    my @valid_addresses = grep { Email::Address::XS->is_obj($_) } @{$addresses};
    if ($carp_invalid and scalar @valid_addresses != scalar @{$addresses}) {
      Carp::carp 'Array element is not an Email::Address::XS object';
      $carp_invalid = 0;
    }
    push @valid_groups, \@valid_addresses;
  }
  push @{$self->{groups}}, @valid_groups;
}

=back

=head1 SEE ALSO

L<RFC 2047|https://tools.ietf.org/html/rfc2047>,
L<RFC 2822|https://tools.ietf.org/html/rfc2822>,
L<Email::MIME>,
L<Email::Address::XS>

=head1 AUTHOR

Pali E<lt>pali@cpan.orgE<gt>

=cut

1;
