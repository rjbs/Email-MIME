#!/usr/bin/perl

use strict;
use warnings;

use Email::MIME::Creator;
use Test::More tests => 5;

my @inner = (
  Email::MIME->create(
    attributes => {
      content_type => "text/plain",
      disposition  => "attachment",
      charset      => "US-ASCII",
    },
    body => "HELLO THERE!",
  ),
  Email::MIME->create(
    attributes => {
      content_type => "text/plain",
      disposition  => "attachment",
      charset      => "US-ASCII",
    },
    body => "GOODBYE THERE!",
  ),
);

my @outer = Email::MIME->create(
  attributes => {
    content_type => "multipart/alternative",
    disposition  => "attachment",
    charset      => "US-ASCII",
  },
  parts => [ @inner ],
);

my $parts = Email::MIME->create(
  attributes => {
    content_type => 'multipart/alternative',
    disposition  => 'attachment',
  },
  parts => [ @outer ],
);
;
my $email = Email::MIME->create(
  attributes => { content_type => 'multipart/related' },
  header     => [ From => 'example@example.example.com' ],
  parts      => [ $parts ],
);

like(
  $email->as_string,
  qr/HELLO THERE/,
  "deeply nested content still found in stringified message",
);

like(
  $email->as_string,
  qr/GOODBYE THERE/,
  "deeply nested content still found in stringified message",
);

is(scalar($email->parts),1,'main contains 1 part');
is(scalar(($email->parts)[0]->parts),1,'outer contains 1 part');
is(scalar((($email->parts)[0]->parts)[0]->parts),2,'inner contains 2 parts');

