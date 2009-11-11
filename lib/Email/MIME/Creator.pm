package Email::MIME::Creator;
use strict;

use vars qw[$VERSION];
$VERSION = '1.902';

use base q[Email::Simple::Creator];
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

__END__

=head1 NAME

Email::MIME::Creator - obsolete do-nothing library

=head1 SYNOPSIS

You don't need to use this module for anything.

=head1 PERL EMAIL PROJECT

This module is maintained by the Perl Email Project.

L<http://emailproject.perl.org/wiki/Email::MIME::Creator>

=head1 ORIGINAL AUTHOR

B<Do not send bug reports to>: Casey West, <F<casey@geeknest.com>>.

=head1 COPYRIGHT

  Copyright (c) 2004 Casey West.  All rights reserved.
  This module is free software; you can redistribute it and/or modify it
  under the same terms as Perl itself.

=cut
