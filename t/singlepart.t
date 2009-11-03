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
$email->header_set(Date => ());

my $expected_string = <<'END_STRING';
From: me
To: you
Subject: test
MIME-Version: 1.0
Content-Transfer-Encoding: base64

ClRoaXMgaXMgbXkgc2luZ2xlcGFydCBtZXNzYWdlLgpJdCdzIGJhc2U2NCBlbmNvZGVkLgo=
END_STRING

my $expected_body = <<'END_BODY';

This is my singlepart message.
It's base64 encoded.
END_BODY

# $expected_body   =~ s/\n/\x0d\x0a/g;
$expected_string =~ s/\n\z/\x0d\x0a/g;

is $email->as_string, $expected_string, 'as_string matches';
is $email->body,      $expected_body, 'body matches';
