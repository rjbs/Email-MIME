use Test::More qw[no_plan];
use strict;
$^W = 1;

use_ok 'Email::MIME::Creator';
use Config;

my $email = Email::MIME->create(
    header => [
      From    => 'me',
      To      => 'you',
      Subject => 'test',
    ],
    parts => [
        q[Part one],
        q[Part two],
        generate_binary_data(),
    ],
);

isa_ok $email, 'Email::MIME';
is scalar($email->parts), 3, 'two parts';

my @parts = $email->parts;

isa_ok $_, 'Email::MIME' for @parts;

like $parts[0]->body, qr/Part one/;
like $parts[1]->body, qr/Part two/;

like $parts[2]->content_type, qr/binary/, 'third part is binary';

sub generate_binary_data {
  my $string = join '', map { chr } 1 .. 255;
  return $string;
}
