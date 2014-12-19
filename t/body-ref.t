use strict;
use warnings;
use Email::MIME;
use Test::More;

for my $ref (0,1) {
  my $prefix = $ref ? 'ref' : 'str';

  my $str = 'x' x 1024
          .  "\nI LIKE PIE\n"
          . 'x' x 1024;

  my $email = Email::MIME->create(
    body => ($ref ? \$str : $str),
    header => [ From => 'fred@example.com' ],
    attributes => {
      encoding     => 'base64',
      content_type => 'application/octet-stream',
      invented     => 'xyzzy',
    },
  );

  cmp_ok(
    length($email->as_string), '>=', 2048,
    "$prefix: email is long enough"
  );
  isnt(index($email->body, 'I LIKE PIE'), -1, "$prefix: target string");

  note $email->as_string;
}

done_testing;
1;

