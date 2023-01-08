use strict;
use warnings;
use utf8;
use Test::More;

use_ok 'Email::MIME';

my $email = Email::MIME->new(<<__MESSAGE__);
Content-Disposition: inline

Engine Engine number nine.
__MESSAGE__

isa_ok $email, 'Email::MIME';


$email->disposition_set('attachment');

is $email->header('Content-Disposition'), 'attachment', 'reset worked';

$email->filename_set( 'loco.pdf' );

like $email->header('Content-Disposition'), qr'^attachment; filename=(?:"loco\.pdf"|loco\.pdf)$', 'filename_set worked';

$email->disposition_set('inline');

like $email->header('Content-Disposition'), qr'^inline; filename=(?:"loco\.pdf"|loco\.pdf)$', 're-reset worked';

$email->filename_set(undef);

is $email->header('Content-Disposition'), 'inline', 'filename_set(undef) worked';

$email->disposition_set('attachment');

$email->filename_set('hah"ha"\'ha\\');
is $email->header('Content-Disposition'), q(attachment; filename="hah\\"ha\\"'ha\\\\");

$email->filename_set('kůň.pdf');
is $email->header('Content-Disposition'), q(attachment; filename*=UTF-8''k%C5%AF%C5%88.pdf; filename=kun.pdf);

done_testing;
