use strict;
use warnings;
use Test::More tests => 12;

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

is $email->header('Content-Type'),
    'text/plain; format="flowed"; name="foo.txt"',
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

is $email->header('Content-Type'),
    'text/plain; bananas="true"; boundary="marker"; format="flowed"; name="foo.txt"',
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

