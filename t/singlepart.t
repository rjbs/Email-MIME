use Test::More qw[no_plan];
use strict;
$^W = 1;

use_ok 'Email::MIME::Creator';

my $email = Email::MIME->create(
    header => [
      From    => 'me',
      To      => 'you',
      Subject => 'test',
    ],
    attributes => {
      encoding => 'base64',
    },
    body => q[
This is my singlepart message.
It's base64 encoded.
] );

isa_ok $email, 'Email::MIME';
$email->header_set(Date => undef);

is $email->as_string, <<__MESSAGE__, 'as_string matches';
From: me
To: you
Subject: test
MIME-Version: 1.0
Content-Transfer-Encoding: base64

ClRoaXMgaXMgbXkgc2luZ2xlcGFydCBtZXNzYWdlLgpJdCdzIGJhc2U2NCBlbmNvZGVkLgo=
__MESSAGE__

is $email->body, <<__MESSAGE__, 'body matches';

This is my singlepart message.
It's base64 encoded.
__MESSAGE__

