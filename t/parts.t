use Test::More tests => 22;

use_ok 'Email::MIME';
use_ok 'Email::MIME::Modifier';

my $email = Email::MIME->new(<<__MESSAGE__);
Content-Disposition: inline

Engine Engine number nine.
__MESSAGE__

isa_ok $email, 'Email::MIME';

is scalar($email->parts), 1, 'only one part';

$email->parts_set([ Email::MIME->new(<<__MESSAGE__), Email::MIME->new(<<__MESSAGE2__) ]);
Content-Type: text/plain

Part one, part one!
__MESSAGE__
Content-Transfer-Encoding: base64

UGFydCB0d28sIHBhcnQgdHdvIQo=
__MESSAGE2__


is scalar($email->parts), 2, 'two parts';
is +($email->parts)[1]->body, qq[Part two, part two!\n], 'part two decoded';

$email->parts_add([ $email->parts ]);

is scalar($email->parts), 4, 'four parts';
is +($email->parts)[1]->body, qq[Part two, part two!\n], 'part two decoded again';
is +($email->parts)[3]->body, qq[Part two, part two!\n], 'part four decoded';

$email->walk_parts(sub {
    my $part = shift;
    isa_ok $part, 'Email::MIME';
    
    $part->encoding_set('base64') if $part->parts <= 1;
    $part->body_set( "foo\nbar" ) if $part->parts <= 1;
});

$email->walk_parts(sub {
    my $part = shift;
    if ( $part->parts <= 1 ) {
        is $part->header('Content-Transfer-Encoding'), 'base64', 'walkdown encoding worked';
        is $part->body, "foo\nbar", 'walkdown body_set worked';
    }
});
