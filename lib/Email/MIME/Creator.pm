package Email::MIME::Creator;
# $Id: Creator.pm,v 1.4 2004/12/24 00:12:49 cwest Exp $
use strict;

use vars qw[$VERSION];
$VERSION = '1.41';

use base q[Email::Simple::Creator];
use Email::MIME;

sub _construct_part {
    my ($class, $body) = @_;

    my $content_type =   ($body =~ /\0/)
                       ? 'application/x-binary'
                       : 'text/plain';
    
    Email::MIME->create(
        attributes => {
            content_type => $content_type,
            encoding     => 'base64', # be safe
        },
        body => $body,
    );
}

package Email::MIME;
use strict;

use vars qw[$CREATOR];
$CREATOR = 'Email::MIME::Creator';

use Email::MIME::Modifier;

sub create {
    my ($class, %args) = @_;

    my $header = '';
    my %headers;
    if ( exists $args{header} ) {
        my @headers = @{ $args{header} };
        pop @headers if @headers % 2 == 1;
        while ( my ($key, $value) = splice @headers, 0, 2 ) {
            $headers{$key} = 1;
            $CREATOR->_add_to_header(\$header, $key, $value);
        }
    }
    $CREATOR->_add_to_header(\$header,
      Date => $CREATOR->_date_header
    ) unless exists $headers{Date};
    $CREATOR->_add_to_header(\$header,
      'MIME-Version' => '1.0',
    );

    my $email = $class->new($header);

    my %attrs = $args{attributes} ? %{$args{attributes}} : ();
    foreach ( qw[content_type charset name format boundary
                 encoding
                 disposition filename] ) {
        my $set = "$_\_set";
        $email->$set( $attrs{$_} ) if exists $attrs{$_};
    }

    if ( $args{parts} && @{$args{parts}} ) {
       foreach my $part ( @{$args{parts}} ) {
           $part = $CREATOR->_construct_part($part)
             unless ref($part);
       }
       $email->parts_set( $args{parts} );
    } elsif ( exists $args{body} ) {
       $email->body_set( $args{body} );
    }
    
    $email;
}

1;

__END__

=head1 NAME

Email::MIME::Creator - Email::MIME constructor for starting anew.

=head1 SYNOPSIS

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
  
  *rcpts = *aux_rcpts = *sekrit_rcpts = sub { 'you@example.com' };

=head1 DESCRIPTION

=head2 Methods

=over 5

=item create

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

C<parts> takes precedence over C<body>, which will set this part's body
if assigned. So, multi part messages shold use the C<parts> parameter
and single part messages should use C<body>.

Back to C<attributes>. The hash keys correspond directly to methods or
modifying a message from C<Email::MIME::Modifier>. The allowed keys are:
content_type, charset, name, format, boundary, encoding, disposition,
and filename. They will be mapped to C<"$attr\_set"> for message
modification.

=back

=head1 SEE ALSO

L<Email::MIME>,
L<Email::MIME::Modifier>,
L<Email::Simple::Creator>,
C<IO::All> or C<File::Slurp> (for file slurping to create parts from strings),
L<perl>.

=head1 AUTHOR

Casey West, <F<casey@geeknest.com>>.

=head1 COPYRIGHT

  Copyright (c) 2004 Casey West.  All rights reserved.
  This module is free software; you can redistribute it and/or modify it
  under the same terms as Perl itself.

=cut
