use strict;
use warnings;
use utf8;
use Test::More tests => 16;

use_ok 'Email::MIME';
use_ok 'Email::MIME::Modifier';
use_ok 'Email::MIME::ContentType';

my $email = Email::MIME->new(<<__MESSAGE__);
Content-Type: text/plain; charset="us-ascii"
__MESSAGE__

sub ct {
  return (
    type    => $_[0], # okay!
    subtype => $_[1], # okay!

    discrete  => $_[0], # dumb!
    composite => $_[1], # dumb!
  );
}

is_deeply( parse_content_type($email->header('Content-Type')), {
    ct(qw(text plain)),
    attributes => {
        charset => 'us-ascii',
    },
}, 'default ct worked' );

$email->charset_set( 'UTF-8' );

is_deeply( parse_content_type($email->header('Content-Type')), {
    ct(qw(text plain)),
    attributes => {
        charset => 'UTF-8',
    },
}, 'ct with new charset worked' );

$email->charset_set( undef );

is_deeply( parse_content_type($email->header('Content-Type')), {
    ct(qw(text plain)),
    attributes => {
    },
}, 'ct with no charset worked' );

$email->format_set( 'flowed' );

is_deeply( parse_content_type($email->header('Content-Type')), {
    ct(qw(text plain)),
    attributes => {
        format => 'flowed',
    },
}, 'ct with format worked' );

$email->name_set( 'foo.txt' );

is_deeply( parse_content_type($email->header('Content-Type')), {
    ct(qw(text plain)),
    attributes => {
        format => 'flowed',
        name => 'foo.txt',
    },
}, 'ct with name worked' );

like $email->header('Content-Type'),
    qr'^text/plain; format=(?:"flowed"|flowed); name=(?:"foo\.txt"|foo\.txt)$',
    'ct format is correct';

$email->boundary_set( 'marker' );

is_deeply( parse_content_type($email->header('Content-Type')), {
    ct(qw(text plain)),
    attributes => {
        boundary => 'marker',
        format => 'flowed',
        name => 'foo.txt',
    },
}, 'ct with boundary worked' );

$email->content_type_attribute_set( 'Bananas' => 'true' );

like $email->header('Content-Type'),
    qr'^text/plain; bananas=(?:"true"|true); boundary=(?:"marker"|marker); format=(?:"flowed"|flowed); name=(?:"foo\.txt"|foo\.txt)$',
    'ct format is correct';

is_deeply( parse_content_type($email->header('Content-Type')), {
    ct(qw(text plain)),
    attributes => {
        bananas => 'true',
        boundary => 'marker',
        format => 'flowed',
        name => 'foo.txt',
    },
}, 'ct with misc. attr (bananas) worked' );

$email->name_set( 'hah"ha"\'ha\\' );

is_deeply( parse_content_type($email->header('Content-Type')), {
    ct(qw(text plain)),
    attributes => {
        bananas => 'true',
        boundary => 'marker',
        format => 'flowed',
        name => 'hah"ha"\'ha\\',
    },
}, 'ct with quotes in name worked' );

like $email->header('Content-Type'),
    qr'^text/plain; bananas=(?:"true"|true); boundary=(?:"marker"|marker); format=(?:"flowed"|flowed); name="hah\\"ha\\"\'ha\\\\"$',
    'ct format is correct';

$email->name_set( 'kůň.pdf' );

is_deeply( parse_content_type($email->header('Content-Type')), {
    ct(qw(text plain)),
    attributes => {
        bananas => 'true',
        boundary => 'marker',
        format => 'flowed',
        name => 'kůň.pdf',
    },
}, 'ct with unicode name worked' );

like $email->header('Content-Type'),
    qr'^text/plain; bananas=(?:"true"|true); boundary=(?:"marker"|marker); format=(?:"flowed"|flowed); name\*=UTF-8\'\'k%C5%AF%C5%88\.pdf; name=kun\.pdf$',
    'ct format is correct';
