use strict;
use warnings;
use Test::More;

use Carp; $SIG{__WARN__} = sub { Carp::cluck @_ };

use_ok 'Email::MIME::Creator';
use_ok 'Email::MIME::ContentType';

sub ct {
  return (
    type    => $_[0], # okay!
    subtype => $_[1], # okay!

    discrete  => $_[0], # dumb!
    composite => $_[1], # dumb!
  );
}

my $hi    = Email::MIME->create(body => "Hi");
my $hello = Email::MIME->create(body => "Hello");
my $howdy = Email::MIME->create(body => "Howdy");

my $all_his = Email::MIME->create(
    attributes => {
      content_type => 'multipart/alternative',
    },
    parts => [ $hi, $howdy, $hello ],
);

is scalar($all_his->parts), 3, 'three parts';

my $email = Email::MIME->create(
    parts => [
        Email::MIME->create(
          attributes => {
            charset => 'UTF-8',
            disposition => 'inline',
          },
          body => "Intro",
        ),
        $all_his,
    ],
);

is scalar($email->parts), 2, 'two parts for email';

is scalar(($email->parts)[-1]->parts), 3, 'three parts for all_his';

my @parts = ($email->parts)[-1]->parts;
is $parts[0]->body_str, 'Hi';
is $parts[1]->body_str, 'Howdy';
is $parts[2]->body_str, 'Hello';

{
  my $all_his = Email::MIME->create(
      attributes => {
        content_type => 'multipart/alternative',
      },
      parts => [ $hi ],
  );

  my @lines = split /\n/, $all_his->debug_structure;
  is(@lines, 2, "2 lines of debug: multipart, then plaintext");
}

{
  open my $qp_problem, '<', 't/Mail/qp-equals'
    or die "can't read qp-equals: $!";

  my $message = do { local $/; <$qp_problem> };
  my $email = Email::MIME->new($message);
  my @parts = $email->subparts;
  unlike($parts[0]->as_string, qr/=\z/, "text: no trailing = from busted QP");
  unlike($parts[1]->as_string, qr/=\z/, "html: no trailing = from busted QP");
}

{
  my $email = Email::MIME->new(<<'END');
Subject: hello
Content-Type: multipart/mixed; boundary="bananas"

Prelude

--bananas
Content-Type: text/plain

This is plain text.
--bananas--

Postlude
END

  like($email->as_string, qr/Prelude/,  "prelude in string");
  like($email->as_string, qr/Postlude/, "postlude in string");

  $email->parts_set([ $email->subparts ]);

  unlike($email->as_string, qr/Prelude/,  "prelude in string");
  unlike($email->as_string, qr/Postlude/, "postlude in string");
}

{
  my $email_str = <<'END';
From: Test <test@test.com>
To: Test <test@test.com>
Subject: Test
Content-Type: multipart/alternative; boundary=90e6ba6e8d06f1723604fc1b809a

--90e6ba6e8d06f1723604fc1b809a
Content-Type: text/plain; charset=UTF-8

Part 1

Part 1a

--90e6ba6e8d06f1723604fc1b809a

Part 2

Part 2a

--90e6ba6e8d06f1723604fc1b809a--
END

  my @emails = (["lf-delimited", $email_str]);

  # Also test with CRLF email
  $email_str =~ s/\n/\r\n/g;

  push @emails, ["crlf-delimited", $email_str];

  for my $test (@emails) {
    my ($desc, $email_str) = @$test;

    note("Testing $desc email");

    my $email = Email::MIME->new($email_str);

    my @parts = $email->subparts;

    is(@parts, 2, 'got 2 parts');

    like($parts[0]->body, qr/^Part 1.*Part 1a\r?$/s, 'Part 1 looks right');
    is_deeply( parse_content_type($parts[0]->header('Content-Type')), {
        ct(qw(text plain)),
        attributes => {
            charset => 'UTF-8',
        },
    }, 'explicit ct worked' );

    like($parts[1]->body, qr/^Part 2.*Part 2a\r?$/s, 'Part 2 looks right');
    is_deeply( parse_content_type($parts[1]->header('Content-Type')), {
        ct(qw(text plain)),
        attributes => {
            charset => 'us-ascii',
        },
    }, 'default ct worked' );
  }
}

done_testing;
