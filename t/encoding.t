use Test::More tests => 14;

use_ok 'Email::MIME';
use_ok 'Email::MIME::Modifier';

my $email = Email::MIME->new(<<__MESSAGE__);
Content-Transfer-Encoding: 7bit
Content-Type: text/plain

Hello World!
I like you!
__MESSAGE__

is $email->body, qq[Hello World!\nI like you!\n], 'plain works';
is $email->body_raw, qq[Hello World!\nI like you!\n], 'plain raw works';
is $email->header('Content-Transfer-Encoding'), '7bit', 'plain encoding works';

$email->encoding_set('base64');

is $email->body, qq[Hello World!\nI like you!\n], 'base64 works';

is(
  $email->body_raw,
  qq[SGVsbG8gV29ybGQhCkkgbGlrZSB5b3UhCg==\x0d\x0a],
  'base64 raw works',
);

is(
  $email->header('Content-Transfer-Encoding'),
  'base64',
  'base64 encoding works',
);

$email->encoding_set('binary');

is(
  $email->body,
  qq[Hello World!\nI like you!\n],
  'binary works',
);

is(
  $email->body_raw,
  qq[Hello World!\nI like you!\n],
  'binary raw works',
);

is(
  $email->header('Content-Transfer-Encoding'),
  'binary',
  'binary encoding works',
);

my $long_line = 'Long line! ' x 100;

$email->encoding_set('quoted-printable');
$email->body_set(<<__MESSAGE__);
$long_line
__MESSAGE__

my $qp_expect = qq{Long line! Long line! Long line! Long line! Long line! Long line! Long line=
! Long line! Long line! Long line! Long line! Long line! Long line! Long li=
ne! Long line! Long line! Long line! Long line! Long line! Long line! Long =
line! Long line! Long line! Long line! Long line! Long line! Long line! Lon=
g line! Long line! Long line! Long line! Long line! Long line! Long line! L=
ong line! Long line! Long line! Long line! Long line! Long line! Long line!=
 Long line! Long line! Long line! Long line! Long line! Long line! Long lin=
e! Long line! Long line! Long line! Long line! Long line! Long line! Long l=
ine! Long line! Long line! Long line! Long line! Long line! Long line! Long=
 line! Long line! Long line! Long line! Long line! Long line! Long line! Lo=
ng line! Long line! Long line! Long line! Long line! Long line! Long line! =
Long line! Long line! Long line! Long line! Long line! Long line! Long line=
! Long line! Long line! Long line! Long line! Long line! Long line! Long li=
ne! Long line! Long line! Long line! Long line! Long line! Long line! Long =
line! Long line! Long line! Long line! Long line!=20\x0d\x0a};

$qp_expect =~ s/=\n/=\x0d\x0a/g;

is(
  $email->body,
  qq[$long_line\x0d\x0a],
  'quoted-printable + body_set works'
);

is(
  $email->body_raw,
  $qp_expect,
  'quoted-printable + body_set raw works',
);

is(
  $email->header('Content-Transfer-Encoding'),
  'quoted-printable',
  'quoted-printble + body_set encoding works',
);
