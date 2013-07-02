use 5.008001;
use strict;
use warnings;
package Email::MIME::Creator;
# ABSTRACT: obsolete do-nothing library

use parent q[Email::Simple::Creator];
use Email::MIME;
use Encode ();

sub _construct_part {
  my ($class, $body) = @_;

  my $is_binary = $body =~ /[\x00\x80-\xFF]/;

  my $content_type = $is_binary ? 'application/x-binary' : 'text/plain';

  Email::MIME->create(
    attributes => {
      content_type => $content_type,
      encoding     => ($is_binary ? 'base64' : ''),  # be safe
    },
    body => $body,
  );
}

1;

=head1 SYNOPSIS

You don't need to use this module for anything.

=cut
