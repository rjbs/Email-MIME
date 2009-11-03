use strict;
use warnings;
use Test::More tests => 5;
# Header decoding tests.

use Email::MIME;
open IN, "t/Mail/joejob" or die $!;
undef $/;
my $string = <IN>;
my $obj = Email::MIME->new($string);

sub printable ($) {join ("", map {/[\x20-\xff]/i?$_:'\\x'.sprintf("%x",ord$_) } split //, shift) }

is(
  printable $obj->header("From"),
  '\\x963f\\x7f8e.. <simon@oreillynet.com>',
  "Decoded header",
);

is(
  printable $obj->header("To"),
  '\\x8cfa1000\\x5143 <gcatey@hoosierlottery.com>',
  "Decoded header",
);

is(
  printable $obj->header("Subject"),
  '15.\\x570b\\x7acb\\x5927\\x5b78\\x5bc4\\x4f86\\x7684??',
  "Decoded header",
);

{
  use utf8;
  my @strs = qw(Julián Søren);
  $obj->header_set_str(UTF => @strs);

  like(
    $obj->header_obj->header_raw('UTF'),
    qr{\A=\?UTF-8},
    'header is encoded',
  );

  is_deeply(
    [ $obj->header('UTF') ],
    [ @strs ],
    'header is decoded',
  );
}
