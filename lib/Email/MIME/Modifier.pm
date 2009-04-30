use strict;
## no critic warnings

package Email::MIME::Modifier;

use vars qw[$VERSION];
$VERSION = '1.444';

use Email::MIME;

package Email::MIME;

use Email::MIME::ContentType;
use Email::MIME::Encodings;
use Email::MessageID;

=head1 NAME

Email::MIME::Modifier - Modify Email::MIME Objects Easily

=head1 VERSION

version 1.444

=head1 SYNOPSIS

  use Email::MIME::Modifier;
  my $email = Email::MIME->new( join "", <> );

  remove_attachments($email);

  sub remove_attachments {
      my $email = shift;
      my @keep;
      foreach my $part ( $email->parts ) {
          push @keep, $part
            unless $part->header('Content-Disposition') =~ /^attachment/;
          remove_attachments($part)
            if $part->content_type =~ /^(?:multipart|message)/;
      }
      $email->parts_set( \@keep );
  }

=head1 DESCRIPTION

Provides a number of useful methods for manipulating MIME messages.

These method are declared in the C<Email::MIME> namespace, and are
used with C<Email::MIME> objects.

=head2 Methods

=over 4

=item content_type_set

  $email->content_type_set( 'text/html' );

Change the content type. All C<Content-Type> header attributes
will remain in tact.

=cut

sub content_type_set {
    my ($self, $ct) = @_;
    my $ct_header = parse_content_type( $self->header('Content-Type') );
    @{$ct_header}{qw[discrete composite]} = split m[/], $ct;
    $self->_compose_content_type( $ct_header );
    $self->_reset_cids;
    return $ct;
}

=pod

=item charset_set

=item name_set

=item format_set

=item boundary_set

  $email->charset_set( 'utf8' );
  $email->name_set( 'some_filename.txt' );
  $email->format_set( 'flowed' );
  $email->boundary_set( undef ); # remove the boundary

These four methods modify common C<Content-Type> attributes. If set to
C<undef>, the attribute is removed. All other C<Content-Type> header
information is preserved when modifying an attribute.

=cut

BEGIN {
  foreach my $attr ( qw[charset name format] ) {
      my $code = sub {
          my ($self, $value) = @_;
          my $ct_header = parse_content_type( $self->header('Content-Type') );
          if ( $value ) {
              $ct_header->{attributes}->{$attr} = $value;
          } else {
              delete $ct_header->{attributes}->{$attr};
          }
          $self->_compose_content_type( $ct_header );
          return $value;
      };

      no strict 'refs'; ## no critic strict
      *{"$attr\_set"} = $code;
  }
}

sub boundary_set {
    my ($self, $value) = @_;
    my $ct_header = parse_content_type( $self->header('Content-Type') );

    if ( $value ) {
        $ct_header->{attributes}->{boundary} = $value;
    } else {
        delete $ct_header->{attributes}->{boundary};
    }
    $self->_compose_content_type( $ct_header );
    
    $self->parts_set([$self->parts]) if $self->parts > 1;
}

=pod

=item encoding_set

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
    $self->body_set( $body );
}

=item body_set

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
      $body = $$body_ref;
    } else {
      $body_ref = \$body;
    }
    my $enc = $self->header('Content-Transfer-Encoding');

    # XXX: This is a disgusting hack and needs to be fixed, probably by a
    # clearer definition and reengineering of Simple construction.  The bug
    # this fixes is an indirect result of the previous behavior in which all
    # Simple subclasses were free to alter the guts of the Email::Simple
    # object. -- rjbs, 2007-07-16
    unless (((caller(1))[3]||'') eq 'Email::Simple::new') {
      $body = Email::MIME::Encodings::encode( $enc, $body )
        unless !$enc || $enc =~ /^(?:7bit|8bit|binary)$/i;
    }

    $self->{body_raw} = $body;
    $self->SUPER::body_set( $body_ref );
}

=pod

=item disposition_set

  $email->disposition_set( 'attachment' );

Alter the C<Content-Disposition> of a message. All header attributes
will remain in tact.

=cut

sub disposition_set {
    my ($self, $dis) = @_;
    $dis ||= 'inline';
    my $dis_header = $self->header('Content-Disposition');
    $dis_header ?
      ($dis_header =~ s/^([^;]+)/$dis/) :
      ($dis_header = $dis);
    $self->header_set('Content-Disposition' => $dis_header);
}

=pod

=item filename_set

  $email->filename_set( 'boo.pdf' );

Sets the filename attribute in the C<Content-Disposition> header. All other
header information is preserved when setting this attribute.

=cut

sub filename_set {
    my ($self, $filename) = @_;
    my $dis_header = $self->header('Content-Disposition');
    my ($disposition, $attrs);
    if ( $dis_header ) {
        ($disposition) = ($dis_header =~ /^([^;]+)/);
        $dis_header =~ s/^$disposition(?:;\s*)?//;
        $attrs = Email::MIME::ContentType::_parse_attributes($dis_header) || {};
    }
    $filename ? $attrs->{filename} = $filename : delete $attrs->{filename};
    $disposition ||= 'inline';
    
    my $dis = $disposition;
    while ( my ($attr, $val) = each %{$attrs} ) {
        $dis .= qq[; $attr="$val"];
    }

    $self->header_set('Content-Disposition' => $dis);
}

=pod

=item parts_set

  $email->parts_set( \@new_parts );

Replaces the parts for an object. Accepts a reference to a list of
C<Email::MIME> objects, representing the new parts. If this message was
originally a single part, the C<Content-Type> header will be changed to
C<multipart/mixed>, and given a new boundary attribute.

=cut

sub parts_set {
    my ($self, $parts) = @_;
    my $body  = q{};

    my $ct_header = parse_content_type($self->header('Content-Type'));

    if (@{$parts} > 1 or $ct_header->{discrete} eq 'multipart') {
        # setup multipart
        $ct_header->{attributes}->{boundary} ||= Email::MessageID->new->user;
        my $bound = $ct_header->{attributes}->{boundary};
        foreach my $part ( @{$parts} ) {
            $body .= "$self->{mycrlf}--$bound$self->{mycrlf}";
            $body .= $part->as_string;
        }
        $body .= "$self->{mycrlf}--$bound--$self->{mycrlf}";
        @{$ct_header}{qw[discrete composite]} = qw[multipart mixed]
          unless grep { $ct_header->{discrete} eq $_ } qw[multipart message];
    } elsif (@$parts == 1) { # setup singlepart
        $body .= $parts->[0]->body;
        @{$ct_header}{qw[discrete composite]} = 
          @{
            parse_content_type($parts->[0]->header('Content-Type'))
           }{qw[discrete composite]};
        $self->encoding_set(
          $parts->[0]->header('Content-Transfer-Encoding')
        );
        delete $ct_header->{attributes}->{boundary};
    }

    $self->_compose_content_type( $ct_header );
    $self->body_set($body);
    $self->fill_parts;
    $self->_reset_cids;
}

=item parts_add

  $email->parts_add( \@more_parts );

Adds MIME parts onto the current MIME part. This is a simple extension
of C<parts_set> to make our lives easier. It accepts an array reference
of additional parts.

=cut

sub parts_add {
    my ($self, $parts) = @_;
    $self->parts_set([
        $self->parts,
        @{$parts},
    ]);
}

=item walk_parts

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
        if ( $part->parts > 1 ) {
            my @subparts;
            for ( $part->parts ) {
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
    for my $attr (sort keys %{$ct_header->{attributes}}) {
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

    if ( $self->parts > 1 ) {
        if ( $ct_header->{composite} eq 'alternative' ) {
            my %cids;
            for my $part ($self->parts) {
              my $cid = defined $part->header('Content-ID')
                      ? $part->header('Content-ID')
                      : q{};
              $cids{ $cid }++
            }
            return if keys(%cids) == 1;

            my $cid = $self->_get_cid;
            $_->header_set('Content-ID' => "<$cid>") for $self->parts;
        } else {
            foreach ( $self->parts ) {
                my $cid = $self->_get_cid;
                $_->header_set('Content-ID' => "<$cid>")
                  unless $_->header('Content-ID');
            }
        }
    }
}

1;

__END__

=pod

=back

=head1 SEE ALSO

L<Email::Simple>, L<Email::MIME>, L<Email::MIME::Encodings>,
L<Email::MIME::ContentType>, L<perl>.

=head1 PERL EMAIL PROJECT

This module is maintained by the Perl Email Project

L<http://emailproject.perl.org/wiki/Email::MIME>

=head1 AUTHOR

Casey West, <F<casey@geeknest.com>>.

=head1 COPYRIGHT

  Copyright (c) 2004 Casey West.  All rights reserved.
  This module is free software; you can redistribute it and/or modify it
  under the same terms as Perl itself.

=cut
