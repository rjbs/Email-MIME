use 5.006;
use strict;
use warnings;

package Email::MIME;
use Email::Simple 2.004;
use base qw(Email::Simple);

use Carp ();
use Email::MessageID;
use Email::MIME::Creator;
use Email::MIME::ContentType;
use Email::MIME::Encodings 1.313;
use Email::MIME::Header;
use Email::MIME::Modifier;
use Encode ();

=head1 NAME

Email::MIME - Easy MIME message parsing.

=head1 VERSION

version 1.902

=head1 SYNOPSIS

  use Email::MIME;
  my $parsed = Email::MIME->new($message);

  my @parts = $parsed->parts; # These will be Email::MIME objects, too.
  my $decoded = $parsed->body;
  my $non_decoded = $parsed->body_raw;

  my $content_type = $parsed->content_type;

...or...

  use Email::MIME::Creator;
  use IO::All;

  # multipart message
  my @parts = (
      Email::MIME->create(
          attributes => {
              filename     => "report.pdf",
              content_type => "application/pdf",
              encoding     => "quoted-printable",
              name         => "2004-financials.pdf",
          },
          body => io( "2004-financials.pdf" )->all,
      ),
      Email::MIME->create(
          attributes => {
              content_type => "text/plain",
              disposition  => "attachment",
              charset      => "US-ASCII",
          },
          body => "Hello there!",
      ),
  );

  my $email = Email::MIME->create(
      header => [ From => 'casey@geeknest.com' ],
      parts  => [ @parts ],
  );

  # nesting parts
  $email->parts_set(
      [
        $email->parts,
        Email::MIME->create( parts => [ @parts ] ),
      ],
  );
  
  # standard modifications
  $email->header_set( 'X-PoweredBy' => 'RT v3.0'      );
  $email->header_set( To            => rcpts()        );
  $email->header_set( Cc            => aux_rcpts()    );
  $email->header_set( Bcc           => sekrit_rcpts() );

  # more advanced
  $_->encoding_set( 'base64' ) for $email->parts;
  
  # Quick multipart creation
  my $quicky = Email::MIME->create(
      header => [
          From => 'my@address',
          To   => 'your@address',
      ],
      parts => [
          q[This is part one],
          q[This is part two],
          q[These could be binary too],
      ],
  );
  
  print $email->as_string;
  
=head1 DESCRIPTION

This is an extension of the L<Email::Simple> module, to handle MIME
encoded messages. It takes a message as a string, splits it up into its
constituent parts, and allows you access to various parts of the
message. Headers are decoded from MIME encoding.

=head1 METHODS

Please see L<Email::Simple> for the base set of methods. It won't take
very long. Added to that, you have:

=cut

our $VERSION = '1.902';

use vars qw[$CREATOR];
$CREATOR = 'Email::MIME::Creator';

sub new {
  my $self = shift->SUPER::new(@_);
  $self->{ct} = parse_content_type($self->content_type);
  $self->parts;
  return $self;
}

=head2 create

  my $single = Email::MIME->create(
    header     => [ ... ],
    attributes => { ... },
    body       => '...',
  );
  
  my $multi = Email::MIME->create(
    header     => [ ... ],
    attributes => { ... },
    parts      => [ ... ],
  );

This method creates a new MIME part. The C<header> parameter is a lis of
headers to include in the message. C<attributes> is a hash of MIME
attributes to assign to the part, and may override portions of the
header set in the C<header> parameter.

The C<parts> parameter is a list reference containing C<Email::MIME>
objects. Elements of the C<parts> list can also be a non-reference
string of data. In that case, an C<Email::MIME> object will be created
for you. Simple checks will determine if the part is binary or not, and
all parts created in this fashion are encoded with C<base64>, just in case.

If C<body> is given instead of C<parts>, it specifies the body to be used for a
flat (subpart-less) MIME message.  It is assumed to be a sequence of octets.

If C<body_str> is given instead of C<body> or C<parts>, it is assumed to be a
character string to be used as the body.  If you provide a C<body_str>
parameter, you B<must> provide C<charset> and C<encoding> attributes.

Back to C<attributes>. The hash keys correspond directly to methods or
modifying a message from C<Email::MIME::Modifier>. The allowed keys are:
content_type, charset, name, format, boundary, encoding, disposition,
and filename. They will be mapped to C<"$attr\_set"> for message
modification.

=cut

sub create {
  my ($class, %args) = @_;

  my $header = '';
  my %headers;
  if (exists $args{header}) {
    my @headers = @{ $args{header} };
    pop @headers if @headers % 2 == 1;
    while (my ($key, $value) = splice @headers, 0, 2) {
      $headers{$key} = 1;
      $CREATOR->_add_to_header(\$header, $key, $value);
    }
  }

  if (exists $args{header_str}) {
    my @headers = @{ $args{header_str} };
    pop @headers if @headers % 2 == 1;
    while (my ($key, $value) = splice @headers, 0, 2) {
      $headers{$key} = 1;

      $value = Encode::encode('MIME-Q', $value, 1);
      $CREATOR->_add_to_header(\$header, $key, $value);
    }
  }

  $CREATOR->_add_to_header(\$header, Date => $CREATOR->_date_header)
    unless exists $headers{Date};
  $CREATOR->_add_to_header(\$header, 'MIME-Version' => '1.0',);

  my %attrs = $args{attributes} ? %{ $args{attributes} } : ();

  # XXX: This is awful... but if we don't do this, then Email::MIME->new will
  # end up calling parse_content_type($self->content_type) which will mean
  # parse_content_type(undef) which, for some reason, returns the default.
  # It's really sort of mind-boggling.  Anyway, the default ends up being
  # q{text/plain; charset="us-ascii"} so that if content_type is in the
  # attributes, but not charset, then charset isn't changedand you up with
  # something that's q{image/jpeg; charset="us-ascii"} and you look like a
  # moron. -- rjbs, 2009-01-20
  if (
    grep { exists $attrs{$_} } qw(content_type charset name format boundary)
  ) {
    $CREATOR->_add_to_header(\$header, 'Content-Type' => 'text/plain',);
  }

  my $email = $class->new($header);

  foreach (qw(
    content_type charset name format boundary
    encoding
    disposition filename
  )) {
    my $set = "$_\_set";
    $email->$set($attrs{$_}) if exists $attrs{$_};
  }

  my $body_args = grep { defined $args{$_} } qw(parts body body_str);
  Carp::confess("only one of parts, body, or body_str may be given")
    if $body_args > 1;

  if ($args{parts} && @{ $args{parts} }) {
    foreach my $part (@{ $args{parts} }) {
      $part = $CREATOR->_construct_part($part)
        unless ref($part);
    }
    $email->parts_set($args{parts});
  } elsif (defined $args{body}) {
    $email->body_set($args{body});
  } elsif (defined $args{body_str}) {
    Carp::confess("body_str was given, but no charset is defined")
      unless my $charset = $attrs{charset};

    Carp::confess("body_str was given, but no encoding is defined")
      unless $attrs{encoding};

    my $body_octets = Encode::encode($attrs{charset}, $args{body_str}, 1);
    $email->body_set($body_octets);
  }

  $email;
}

sub as_string {
  my $self = shift;
  return $self->__head->as_string
    . ($self->{mycrlf} || "\n")  # XXX: replace with ->crlf
    . $self->body_raw;
}

sub parts {
  my $self = shift;

  $self->fill_parts unless $self->{parts};

  my @parts = @{ $self->{parts} };
  @parts = $self unless @parts;
  return @parts;
}

sub subparts {
  my ($self) = @_;

  $self->fill_parts unless $self->{parts};
  my @parts = @{ $self->{parts} };
  return @parts;
}

sub fill_parts {
  my $self = shift;

  if (
    $self->{ct}{discrete} eq "multipart"
    or $self->{ct}{discrete} eq "message"
  ) {
    $self->parts_multipart;
  } else {
    $self->parts_single_part;
  }

  return $self;
}

sub body {
  my $self = shift;
  my $body = $self->SUPER::body;
  my $cte  = $self->header("Content-Transfer-Encoding") || '';
  
  $cte =~ s/\A\s+//;
  $cte =~ s/\s+\z//;
  $cte =~ s/;.+//; # For S/MIME, etc.

  return $body unless $cte;

  if (!$self->force_decode_hook and $cte =~ /\A(?:7bit|8bit|binary)\z/i) {
    return $body;
  }

  $body = $self->decode_hook($body) if $self->can("decode_hook");

  $body = Email::MIME::Encodings::decode($cte, $body);
  return $body;
}

sub parts_single_part {
  my $self = shift;
  $self->{parts} = [];
  return $self;
}

sub body_raw {
  return $_[0]->{body_raw} || $_[0]->SUPER::body;
}

sub body_str {
  my ($self) = @_;
  my $encoding = $self->{ct}{attributes}{charset};

  unless ($encoding) {
    if ($self->{ct}{discrete} eq 'text'
      and
      ($self->{ct}{composite} eq 'plain' or $self->{ct}{composite} eq 'html')
    ) {

      # assume that plaintext or html without ANY charset is us-ascii
      return $self->body;
    }

    Carp::confess("can't get body as a string for " . $self->content_type);
  }

  my $str = Encode::decode($encoding, $self->body, 1);
  return $str;
}

sub parts_multipart {
  my $self     = shift;
  my $boundary = $self->{ct}->{attributes}->{boundary};

  # Take a message, join all its lines together.  Now try to Email::MIME->new
  # it with 1.861 or earlier.  Death!  It tries to recurse endlessly on the
  # body, because every time it splits on boundary it gets itself. Obviously
  # that means it's a bogus message, but a mangled result (or exception) is
  # better than endless recursion. -- rjbs, 2008-01-07
  return $self->parts_single_part
    unless $boundary and $self->body_raw =~ /^--\Q$boundary\E\s*$/sm;

  $self->{body_raw} = $self->SUPER::body;

  # rfc1521 7.2.1
  my ($body, $epilogue) = split /^--\Q$boundary\E--\s*$/sm, $self->body_raw, 2;

  my @bits = split /^--\Q$boundary\E\s*$/sm, ($body || '');

  $self->SUPER::body_set(undef);

  # If there are no headers in the potential MIME part, it's just part of the
  # body.  This is a horrible hack, although it's debateable whether it was
  # better or worse when it was $self->{body} = shift @bits ... -- rjbs,
  # 2006-11-27
  $self->SUPER::body_set(shift @bits) if ($bits[0] || '') !~ /.*:.*/;

  my $bits = @bits;

  my @parts;
  for my $bit (@bits) {
    $bit =~ s/\A[\n\r]+//smg;
    my $email = (ref $self)->new($bit);
    push @parts, $email;
  }

  $self->{parts} = \@parts;

  return @{ $self->{parts} };
}

sub force_decode_hook { 0 }
sub decode_hook       { return $_[1] }
sub content_type      { scalar shift->header("Content-type"); }

sub debug_structure {
  my ($self, $level) = @_;
  $level ||= 0;
  my $rv = " " x (5 * $level);
  $rv .= "+ " . $self->content_type . "\n";
  my @parts = $self->parts;
  if (@parts > 1) { $rv .= $_->debug_structure($level + 1) for @parts; }
  return $rv;
}

my %gcache;

sub filename {
  my ($self, $force) = @_;
  return $gcache{$self} if exists $gcache{$self};

  my $dis = $self->header("Content-Disposition") || '';
  my $attrs
    = $dis =~ s/^.*?;//
    ? Email::MIME::ContentType::_parse_attributes($dis)
    : {};
  my $name = $attrs->{filename}
    || $self->{ct}{attributes}{name};
  return $name if $name or !$force;
  return $gcache{$self} = $self->invent_filename(
    $self->{ct}->{discrete} . "/" . $self->{ct}->{composite});
}

my $gname = 0;

sub invent_filename {
  my ($self, $ct) = @_;
  require MIME::Types;
  my $type = MIME::Types->new->type($ct);
  my $ext = $type && (($type->extensions)[0]);
  $ext ||= "dat";
  return "attachment-$$-" . $gname++ . ".$ext";
}

sub default_header_class { 'Email::MIME::Header' }

sub header_str_set {
  my $self = shift;
  $self->header_obj->header_str_set(@_);
}

=head2 content_type_set

  $email->content_type_set( 'text/html' );

Change the content type. All C<Content-Type> header attributes
will remain in tact.

=cut

sub content_type_set {
  my ($self, $ct) = @_;
  my $ct_header = parse_content_type($self->header('Content-Type'));
  @{$ct_header}{qw[discrete composite]} = split m[/], $ct;
  $self->_compose_content_type($ct_header);
  $self->_reset_cids;
  return $ct;
}

=head2 charset_set

=head2 name_set

=head2 format_set

=head2 boundary_set

  $email->charset_set( 'utf8' );
  $email->name_set( 'some_filename.txt' );
  $email->format_set( 'flowed' );
  $email->boundary_set( undef ); # remove the boundary

These four methods modify common C<Content-Type> attributes. If set to
C<undef>, the attribute is removed. All other C<Content-Type> header
information is preserved when modifying an attribute.

=cut

BEGIN {
  foreach my $attr (qw[charset name format]) {
    my $code = sub {
      my ($self, $value) = @_;
      my $ct_header = parse_content_type($self->header('Content-Type'));
      if ($value) {
        $ct_header->{attributes}->{$attr} = $value;
      } else {
        delete $ct_header->{attributes}->{$attr};
      }
      $self->_compose_content_type($ct_header);
      return $value;
    };

    no strict 'refs';  ## no critic strict
    *{"$attr\_set"} = $code;
  }
}

sub boundary_set {
  my ($self, $value) = @_;
  my $ct_header = parse_content_type($self->header('Content-Type'));

  if ($value) {
    $ct_header->{attributes}->{boundary} = $value;
  } else {
    delete $ct_header->{attributes}->{boundary};
  }
  $self->_compose_content_type($ct_header);

  $self->parts_set([ $self->parts ]) if $self->parts > 1;
}

=head2 encoding_set

  $email->encoding_set( 'base64' );
  $email->encoding_set( 'quoted-printable' );
  $email->encoding_set( '8bit' );

Convert the message body and alter the C<Content-Transfer-Encoding>
header using this method. Your message body, the output of the C<body()>
method, will remain the same. The raw body, output with the C<body_raw()>
method, will be changed to reflect the new encoding.

=cut

sub encoding_set {
  my ($self, $enc) = @_;
  $enc ||= '7bit';
  my $body = $self->body;
  $self->header_set('Content-Transfer-Encoding' => $enc);
  $self->body_set($body);
}

=head2 body_set

  $email->body_set( $unencoded_body_string );

This method will encode the new body you send using the encoding
specified in the C<Content-Transfer-Encoding> header, then set
the body to the new encoded body.

This method overrides the default C<body_set()> method.

=cut

sub body_set {
  my ($self, $body) = @_;
  my $body_ref;

  if (ref $body) {
    $body_ref = $body;
    $body     = $$body_ref;
  } else {
    $body_ref = \$body;
  }
  my $enc = $self->header('Content-Transfer-Encoding');

  # XXX: This is a disgusting hack and needs to be fixed, probably by a
  # clearer definition and reengineering of Simple construction.  The bug
  # this fixes is an indirect result of the previous behavior in which all
  # Simple subclasses were free to alter the guts of the Email::Simple
  # object. -- rjbs, 2007-07-16
  unless (((caller(1))[3] || '') eq 'Email::Simple::new') {
    $body = Email::MIME::Encodings::encode($enc, $body)
      unless !$enc || $enc =~ /^(?:7bit|8bit|binary)\s*$/i;
  }

  $self->{body_raw} = $body;
  $self->SUPER::body_set($body_ref);
}

=head2 body_str_set

  $email->body_str_set($unicode_str);

This method behaves like C<body_set>, but assumes that the given value is a
Unicode string that should be encoded into the message's charset before being
set.  If the charset can't be determined, an exception is thrown.

=cut

sub body_str_set {
  my ($self, $body_str) = @_;

  my $ct = parse_content_type($self->content_type);
  Carp::confess("body_str was given, but no charset is defined")
    unless my $charset = $ct->{attributse}{charset};

  my $body_octets = Encode::encode($charset, $body_str, 1);
  $self->body_set($body_octets);
}

=head2 disposition_set

  $email->disposition_set( 'attachment' );

Alter the C<Content-Disposition> of a message. All header attributes
will remain in tact.

=cut

sub disposition_set {
  my ($self, $dis) = @_;
  $dis ||= 'inline';
  my $dis_header = $self->header('Content-Disposition');
  $dis_header
    ? ($dis_header =~ s/^([^;]+)/$dis/)
    : ($dis_header = $dis);
  $self->header_set('Content-Disposition' => $dis_header);
}

=head2 filename_set

  $email->filename_set( 'boo.pdf' );

Sets the filename attribute in the C<Content-Disposition> header. All other
header information is preserved when setting this attribute.

=cut

sub filename_set {
  my ($self, $filename) = @_;
  my $dis_header = $self->header('Content-Disposition');
  my ($disposition, $attrs);
  if ($dis_header) {
    ($disposition) = ($dis_header =~ /^([^;]+)/);
    $dis_header =~ s/^$disposition(?:;\s*)?//;
    $attrs = Email::MIME::ContentType::_parse_attributes($dis_header) || {};
  }
  $filename ? $attrs->{filename} = $filename : delete $attrs->{filename};
  $disposition ||= 'inline';

  my $dis = $disposition;
  while (my ($attr, $val) = each %{$attrs}) {
    $dis .= qq[; $attr="$val"];
  }

  $self->header_set('Content-Disposition' => $dis);
}

=head2 parts_set

  $email->parts_set( \@new_parts );

Replaces the parts for an object. Accepts a reference to a list of
C<Email::MIME> objects, representing the new parts. If this message was
originally a single part, the C<Content-Type> header will be changed to
C<multipart/mixed>, and given a new boundary attribute.

=cut

sub parts_set {
  my ($self, $parts) = @_;
  my $body = q{};

  my $ct_header = parse_content_type($self->header('Content-Type'));

  if (@{$parts} > 1 or $ct_header->{discrete} eq 'multipart') {

    # setup multipart
    $ct_header->{attributes}->{boundary} ||= Email::MessageID->new->user;
    my $bound = $ct_header->{attributes}->{boundary};
    foreach my $part (@{$parts}) {
      $body .= "$self->{mycrlf}--$bound$self->{mycrlf}";
      $body .= $part->as_string;
    }
    $body .= "$self->{mycrlf}--$bound--$self->{mycrlf}";
    @{$ct_header}{qw[discrete composite]} = qw[multipart mixed]
      unless grep { $ct_header->{discrete} eq $_ } qw[multipart message];
  } elsif (@$parts == 1) {  # setup singlepart
    $body .= $parts->[0]->body;
    @{$ct_header}{qw[discrete composite]}
      = @{ parse_content_type($parts->[0]->header('Content-Type')) }
      {qw[discrete composite]};
    $self->encoding_set($parts->[0]->header('Content-Transfer-Encoding'));
    delete $ct_header->{attributes}->{boundary};
  }

  $self->_compose_content_type($ct_header);
  $self->body_set($body);
  $self->fill_parts;
  $self->_reset_cids;
}

=head2 parts_add

  $email->parts_add( \@more_parts );

Adds MIME parts onto the current MIME part. This is a simple extension
of C<parts_set> to make our lives easier. It accepts an array reference
of additional parts.

=cut

sub parts_add {
  my ($self, $parts) = @_;
  $self->parts_set([ $self->parts, @{$parts}, ]);
}

=head2 walk_parts

  $email->walk_parts(sub {
      my $part = @_;
      return if $part->parts > 1; # multipart
      
      if ( $part->content_type =~ m[text/html] ) {
          my $body = $part->body;
          $body =~ s/<link [^>]+>//; # simple filter example
          $part->body_set( $body );
      }
  });

Walks through all the MIME parts in a message and applies a callback to
each. Accepts a code reference as its only argument. The code reference
will be passed a single argument, the current MIME part within the
top-level MIME object. All changes will be applied in place.

=cut

sub walk_parts {
  my ($self, $callback) = @_;

  my $walk;
  $walk = sub {
    my ($part) = @_;
    $callback->($part);
    if ($part->parts > 1) {
      my @subparts;
      for ($part->parts) {
        push @subparts, $walk->($_);
      }
      $part->parts_set(\@subparts);
    }
    return $part;
  };

  $walk->($self);
}

sub _compose_content_type {
  my ($self, $ct_header) = @_;
  my $ct = join q{/}, @{$ct_header}{qw[discrete composite]};
  for my $attr (sort keys %{ $ct_header->{attributes} }) {
    $ct .= qq[; $attr="$ct_header->{attributes}{$attr}"];
  }
  $self->header_set('Content-Type' => $ct);
  $self->{ct} = $ct_header;
}

sub _get_cid {
  Email::MessageID->new->address;
}

sub _reset_cids {
  my ($self) = @_;

  my $ct_header = parse_content_type($self->header('Content-Type'));

  if ($self->parts > 1) {
    if ($ct_header->{composite} eq 'alternative') {
      my %cids;
      for my $part ($self->parts) {
        my $cid
          = defined $part->header('Content-ID')
          ? $part->header('Content-ID')
          : q{};
        $cids{$cid}++;
      }
      return if keys(%cids) == 1;

      my $cid = $self->_get_cid;
      $_->header_set('Content-ID' => "<$cid>") for $self->parts;
    } else {
      foreach ($self->parts) {
        my $cid = $self->_get_cid;
        $_->header_set('Content-ID' => "<$cid>")
          unless $_->header('Content-ID');
      }
    }
  }
}

1;

__END__


=head2 header_str_set

  $email->header_str_set($header_name => @value_strings);

This behaves like C<header_set>, but expects Unicode (character) strings as the
values to set, rather than pre-encoded byte strings.  It will encode them as
MIME encoded-words if they contain any control or 8-bit characters.

=head2 parts

This returns a list of C<Email::MIME> objects reflecting the parts of the
message. If it's a single-part message, you get the original object back.

In scalar context, this method returns the number of parts.

=head2 subparts

This returns a list of C<Email::MIME> objects reflecting the parts of the
message.  If it's a single-part message, this method returns an empty list.

In scalar context, this method returns the number of subparts.

=head2 body

This decodes and returns the body of the object I<as a byte string>. For
top-level objects in multi-part messages, this is highly likely to be something
like "This is a multi-part message in MIME format."

=head2 body_str

This decodes both the Content-Transfer-Encoding layer of the body (like the
C<body> method) as well as the charset encoding of the body (unlike the C<body>
method), returning a Unicode string.

If the charset is known, it is used.  If there is no charset but the content
type is either C<text/plain> or C<text/html>, us-ascii is assumed.  Otherwise,
an exception is thrown.

=head2 body_raw

This returns the body of the object, but doesn't decode the transfer encoding.

=head2 decode_hook

This method is called before the L<Email::MIME::Encodings> C<decode> method, to
decode the body of non-binary messages (or binary messages, if the
C<force_decode_hook> method returns true).  By default, this method does
nothing, but subclasses may define behavior.

This method could be used to implement the decryption of content in secure
email, for example.

=head2 content_type

This is a shortcut for access to the content type header.

=head2 filename

This provides the suggested filename for the attachment part. Normally
it will return the filename from the headers, but if C<filename> is
passed a true parameter, it will generate an appropriate "stable"
filename if one is not found in the MIME headers.

=head2 invent_filename

  my $filename = Email::MIME->invent_filename($content_type);

This routine is used by C<filename> to generate filenames for attached files.
It will attempt to choose a reasonable extension, falling back to F<dat>.

=head2 debug_structure

  my $description = $email->debug_structure;

This method returns a string that describes the structure of the MIME entity.
For example:

  + multipart/alternative; boundary="=_NextPart_2"; charset="BIG-5"
    + text/plain
    + text/html

=head1 TODO

All of the Email::MIME-specific guts should move to a single entry on the
object's guts.  This will require changes to both Email::MIME and
L<Email::MIME::Modifier>, sadly.

=head1 SEE ALSO

L<Email::Simple>, L<Email::MIME::Modifier>, L<Email::MIME::Creator>.

=head1 PERL EMAIL PROJECT

This module is maintained by the Perl Email Project

L<http://emailproject.perl.org/wiki/Email::MIME>

=head1 AUTHOR

Casey West, C<casey@geeknest.com>

Simon Cozens, C<simon@cpan.org> (retired)

This software is copyright (c) 2004 by Simon Cozens.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

=head1 THANKS

This module was generously sponsored by Best Practical
(http://www.bestpractical.com/) and Pete Sergeant.

=cut
