use strict;
use warnings;
use Test::More;

use_ok 'Email::MIME::Creator';

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
Content-Type: multipart/mixed; boundary="0"

Prelude

--0
Content-Type: text/plain

This is plain text.
--0--

Postlude
END

  like($email->as_string, qr/Prelude/,  "prelude in string");
  like($email->as_string, qr/Postlude/, "postlude in string");

  my @p;
  $email->walk_parts(sub {
    my $str = eval { $_[0]->body_str };
    push @p, $str if defined $str;
  });
  is_deeply(\@p, ['This is plain text.']);

  $email->parts_set([ $email->subparts ]);

  unlike($email->as_string, qr/Prelude/,  "prelude in string");
  unlike($email->as_string, qr/Postlude/, "postlude in string");
}

done_testing;
