use strict;
use warnings;
use utf8;
use Test::More;

BEGIN {
  plan skip_all => 'Email::Address::XS is required for this test' unless eval { require Email::Address::XS };
  plan 'no_plan';
}

BEGIN {
  use_ok('Email::MIME::Encode');
}

is(
  Email::MIME::Encode::maybe_mime_encode_header('To', '"Name ☺" <user@host>'),
  '=?UTF-8?B?TmFtZSDimLo=?= <user@host>',
  'Email::MIME::Encode::maybe_mime_encode_header works without "use Email::MIME::Header"'
);
