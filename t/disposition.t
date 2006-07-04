use Test::More tests => 7;

use_ok 'Email::MIME';
use_ok 'Email::MIME::Modifier';

my $email = Email::MIME->new(<<__MESSAGE__);
Content-Disposition: inline

Engine Engine number nine.
__MESSAGE__

isa_ok $email, 'Email::MIME';


$email->disposition_set('attachment');

is $email->header('Content-Disposition'), 'attachment', 'reset worked';

$email->filename_set( 'loco.pdf' );

is $email->header('Content-Disposition'), 'attachment; filename="loco.pdf"', 'filename_set worked';

$email->disposition_set('inline');

is $email->header('Content-Disposition'), 'inline; filename="loco.pdf"', 're-reset worked';

$email->filename_set(undef);

is $email->header('Content-Disposition'), 'inline', 'filename_set(undef) worked';

