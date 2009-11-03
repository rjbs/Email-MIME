use Test::More tests => 19;
use strict;
$^W = 1;

use_ok 'Email::MIME::Modifier';

my $email = Email::MIME->new(<<'__MESSAGE__');
From: me@example.com
To: you@example.com
__MESSAGE__

isa_ok $email, 'Email::MIME';
my $email2 = Email::MIME->new($email->as_string);
isa_ok $email2, 'Email::MIME';

my @parts = ( q[Part one], q[Part two] );

$email->content_type_set('multipart/mixed');
$email->parts_set([map Email::MIME->new("Header: Foo\n\n$_"), @parts]);

is scalar($email->parts), 2, 'two parts';
like $email->content_type, qr[multipart/mixed], 'proper content_type';

my @email_cids;
$email->walk_parts(sub{
    return if $_[0] == $email;
    push @email_cids, shift->header('Content-ID');
});

is scalar(@email_cids), 2, 'two content ids';
ok $_, "$_ defined" for @email_cids;
isnt $email_cids[0], $email_cids[1], 'not the same';




$email2->parts_set([map Email::MIME->new("Header: Foo\n\n$_"), @parts]);
$email2->content_type_set('multipart/alternative');

is scalar($email2->parts), 2, 'two parts';
like $email2->content_type, qr[multipart/alternative], 'proper content_type';

my @email2_cids;
$email2->walk_parts(sub{
    return if $_[0] == $email2;
    push @email2_cids, shift->header('Content-ID');
});

is scalar(@email2_cids), 2, 'two content ids';
ok $_, "$_ defined" for @email2_cids;
is $email2_cids[0], $email2_cids[1], 'the same';

$email2->content_type_set('multipart/alternative');
$email2->parts_set([map Email::MIME->new("Header: Foo\n\n$_"), $parts[0]]);

is scalar($email2->parts), 1, 'one part';
like $email2->content_type, qr[multipart/alternative], 'proper content_type';

$email2->content_type_set('text/plain');
$email2->parts_set([map Email::MIME->new("Header: Foo\n\n$_"), $parts[0]]);

is scalar($email2->parts), 1, 'one part';
like $email2->content_type, qr[text/plain], 'proper content_type';
