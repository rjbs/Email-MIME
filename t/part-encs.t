use strict;
use warnings;
use Test::More;

plan skip_all => "these tests require Email::MIME::Creator 1.43"
  unless eval "use Email::MIME::Creator 1.43; 1";

plan tests => 11;

use_ok 'Email::MIME';
use_ok 'Email::MIME::Modifier';
use_ok 'Email::MIME::Creator';

use Symbol qw(gensym);

my $file = do {
  my $fh = gensym;
  open $fh, "<t/files/readme.txt.gz" or die "can't open attachment file: $!";
  binmode $fh;
  local $/;
  <$fh>;
};

{
  my $two_parts = Email::MIME->create(parts => [ $file, $file ]);
  my @parts = $two_parts->parts;

  for my $part (@parts) {
    is(
      $part->header('Content-Transfer-Encoding'),
      'base64',
      "binary part got base64 encoded (1/2)",
    );

    is(
      $part->header('Content-Transfer-Encoding'),
      'base64',
      "binary part got base64 encoded (1/2)",
    );
  }
}

{
  my $one_part = Email::MIME->create(parts => [ $file ]);
  my @parts = $one_part->parts;

  for my $part (@parts) {
    is(
      $part->header('Content-Transfer-Encoding'),
      'base64',
      "binary part got base64 encoded (1/1)",
    );
  }
}

{
  my $one_part = Email::MIME->create(parts => [ "This is a normal string\n"  ]);
  my @parts = $one_part->parts;

  for my $part (@parts) {
    is(
      $part->header('Content-Transfer-Encoding'),
      '7bit',
      "single text part got (stayed) 7bit encoded (1/1)",
    );
  }
}

{
  my $two_parts = Email::MIME->create(
    parts => [
      "This is a normal string\n",
      $file,
    ]
  );

  my @parts = $two_parts->parts;

  is(
    $parts[0]->header('Content-Transfer-Encoding'),
    '7bit',
    "text part got (stayed) 7bit encoded (1/2)",
  );

  is(
    $parts[1]->header('Content-Transfer-Encoding'),
    'base64',
    "binary part got base64 encoded (2/2)",
  );
}
