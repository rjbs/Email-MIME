#!perl
# vim:ft=perl
use strict;
use warnings;

use Test::More 'no_plan';
use Email::MIME::Encodings;

use_ok("Email::MIME");

open IN, "t/Mail/mail-1" or die $!;

my $string = do { local $/; <IN> };

my $email = Email::MIME->new($string);
isa_ok($email, "Email::MIME");

my ($part) = $email->parts;
isa_ok($part, "Email::MIME");

my $body = $part->body;

is(
  $body,
  Email::MIME::Encodings::decode(base64 => $email->body_raw),
  "Internally consistent"
);

open(GIF, "t/Mail/att-1.gif") or die $!;
binmode GIF;
my $gif = do { local $/; <GIF> };
is($body, $gif, "Externally consistent");
is($email->filename, "1.gif", "Filename is correct");

my $header  = $email->header('X-MultiHeader');
my @headers = $email->header('X-MultiHeader');

ok $header, 'got back a header in scalar context';
ok !ref($header), 'header in scalar context is not ref';

is scalar(@headers), 3, 'got all three back in list context';

# This test would be stupider if it hadn't broken in a release.
# There are to many reliances on Email::Simple guts, at this point.
#   -- rjbs, 2006-10-15
eval { $email->as_string };
is($@, '', "we can stringify without dying");
