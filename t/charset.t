use strict;
use warnings;
use utf8;
use Test::More;
use Email::MIME;

my $email = Email::MIME->create(
  header    => [
    From    => q{"Your name" <your_email@some-domain.com>},
    To      => q{"The recipients's name" <recipients_email@some-domain.com>},
    Subject => q{Lorem ipsum dolor}
  ],
  parts => [
    Email::MIME->create(
      attributes => {
        encoding     => 'quoted-printable',
        content_type => 'text/plain',
        charset      => 'UTF-8'
      },
      body_str => qq{Queensrÿche playing mañana.\n},
    ),
  ],
);

like(
  $email->header('Content-type'),
  qr/utf-8/i,
  "we don't kill the charset on single 'parts' arg",
);

like(
  $email->body_str,
  qr/\xFF/,
  "...and the decoded body still has U+00FF in it",
);

ok(1);
done_testing;
