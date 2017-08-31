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

  my @pairs = $email->header_str_pairs;
  my @idx   = grep { $_ % 2 == 0 and $pairs[$_] eq 'Test' } (0..$#pairs);
  is(@idx, 3, 'there are three entries for Test in header_str_pairs');
  is($pairs[$idx[0]+1], 'Julián', "1st header decodes to J...");
  is($pairs[$idx[1]+1], '=?UTF-8?B?SnVsacOhbg==?=', "2nd header decodes to =?..?=");
  is($pairs[$idx[2]+1], 'Julián', "3rd header decodes to J...");
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

SKIP: {
  skip 'Email::Address::XS is required for this test', 1 unless eval { require Email::Address::XS };
  my @subjects = (
    "test test test test test test test test tést te (12 34)", # unicode
    "test test test test test test test test test te (12 34)", # not
  );

  my @tos = (
    'Döy <test@example.com>', # unicode
    'Doy <test@example.com>', # not
    '"<look@like.address>," <test@example.com>', # address-like pattern in phrase
    '"Döy <look@like.address>," <test@example.com>', # unicode address-like pattern in phrase
    'adam@äli.as',            # unicode host
    'Ädam <adam@äli.as>',     # unicode phrase and host
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
      $email->header_str_set('Subject', $subject);
      is(scalar($email->header_str('Subject')), $subject,
         "Subject header is correct");
      is(scalar($email->header('To')), $to,
         "To header is correct");
      $email->header_str_set('To', $to);
      is(scalar($email->header_str('To')), $to,
         "To header is correct");
      if ($to =~ /adam/) {
        like($email->header_raw('To'), qr/adam\@xn--li-uia.as/,
           'To raw header is correct');
      } else {
        like($email->as_string, qr/test\@example\.com/,
             "address isn't encoded");
      }
      like($email->as_string, qr/\A\p{ASCII}*\z/,
           "email doesn't contain any non-ascii characters");
    }
  }
}
