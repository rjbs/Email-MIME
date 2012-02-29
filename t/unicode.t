use strict;
use warnings;
use Test::More 'no_plan';
use utf8;

use Encode;

require_ok 'Email::MIME::Creator';

{
  my $email = Email::MIME->create(
    header => [
      Test => '=?UTF-8?B?SnVsacOhbg==?=',
    ],
    header_str => [
      Test => '=?UTF-8?B?SnVsacOhbg==?=',
      Test => 'Julián',
    ],

    body => "Hi",
  );

  my @header = $email->header('Test');
  is($header[0], 'Julián', "1st header decodes to J...");
  is($header[1], '=?UTF-8?B?SnVsacOhbg==?=', "2nd header decodes to =?..?=");
  is($header[2], 'Julián', "3rd header decodes to J...");
}

{
  my $crlf = "\x0d\x0a";
  my $name = 'Ricardo Julián Besteiro Signes';
  my $body = "Dear $name,${crlf}${crlf}You're great!${crlf}${crlf}"
           . "-- $crlf$name$crlf";

  my $email = Email::MIME->create(
    header_str => [
      'To-Name'   => $name,
      'From-Name' => 'Ricardo J. B. Signes',
    ],
    attributes => {
      charset  => 'utf-8',
      encoding => 'quoted-printable',
    },
    body_str   => $body,
  );

  ok($email->body ne $body, "the ->body method doesn't get us the input");
  is($email->body_str, $body, "the ->body_str does get us the input");
  is(
    length $email->body_str,
    length $body,
    "...and lengths are the same",
  );
}

{
  my @subjects = (
    "test test test test test test test test tést te (12 34)", # unicode
    "test test test test test test test test test te (12 34)", # not
  );

  my @tos = (
    'Döy <test@example.com>', # unicode
    'Doy <test@example.com>', # not
  );

  for my $subject (@subjects) {
    for my $to (@tos) {
      my $email = Email::MIME->create(
        header_str => [
          Subject => $subject,
          To      => $to,
        ],
        body => "...",
      );
      is(scalar($email->header('Subject')), $subject,
         "Subject header is correct");
      is(scalar($email->header('To')), $to,
         "To header is correct");
      like($email->as_string, qr/test\@example\.com/,
           "address isn't encoded");
      like($email->as_string, qr/\p{ASCII}/,
           "email doesn't contain any non-ascii characters");
    }
  }
}
