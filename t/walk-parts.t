use strict;
use warnings;

use Test::More 0.88;

use Email::MIME;

my $called_parts_set = 0;
{
  package Email::MIME::Metered;
  BEGIN { our @ISA = qw(Email::MIME); }
  sub parts_set {
    $called_parts_set++ if (caller(2))[3] eq 'Email::MIME::walk_parts';
    my $self = shift;
    $self->SUPER::parts_set(@_);
  }
}

my $email;
{
  local $/;
  $email = Email::MIME::Metered->new(<DATA>);
}

my @types;

$email->walk_parts(sub {
  my ($part) = @_;
  push @types, $part->content_type;
});

is_deeply(
  \@types,
  [
    'multipart/mixed;  boundary="----=_Part_13986_26026450.1275360964578"',
    'multipart/related;  boundary="----=_Part_13987_10977679.1275360964578"',
    'text/html; charset=iso-8859-1',
    'image/gif',
  ],
  "walk_parts descends into all parts",
);

is($called_parts_set, 0, "didn't parts_set");

my $i = 1;
$email->walk_parts(sub {
  return if $i--;
  $_[0] = Email::MIME::Metered->create(
    header => [
      From    => 'me',
      To      => 'you',
      Subject => 'test',
    ],
    parts => [
      q[Part one],
      q[Part two],
      (join '', map { chr } 1 .. 255),
    ],
  );
});

is($called_parts_set, 1, "called parts_set once");
like($email->as_string, qr/Part one/);

$email->walk_parts(sub {
  if ($_[0]->body and $_[0]->body eq 'Part one') {
    $_[0] = Email::MIME->create(
      body => 'Part ONE',
    );
  }
});
like($email->as_string, qr/Part ONE/);

done_testing;

__DATA__
Received: from mx ([192.168.16.15])
	by mbox (Dovecot) with LMTP id 3iaQF1x2BE
	for <user@domain>; Tue, 01 Jun 2010 04:54:20 +0200
Date: Tue, 1 Jun 2010 04:56:04 +0200 (CEST)
From: Username <user@example.com>
To: USer2 <user2@example.com>
Subject: Sample mail
Mime-Version: 1.0
Content-Type: multipart/mixed; 
	boundary="----=_Part_13986_26026450.1275360964578"

------=_Part_13986_26026450.1275360964578
Content-Type: multipart/related; 
	boundary="----=_Part_13987_10977679.1275360964578"

------=_Part_13987_10977679.1275360964578
Content-Type: text/html; charset=iso-8859-1
Content-Transfer-Encoding: 7bit

<html>mail</html>

------=_Part_13987_10977679.1275360964578
Content-Type: image/gif
Content-Transfer-Encoding: base64
Content-ID: default.large.gif

R0lGODlhNgAkAPcAAAAA
------=_Part_13987_10977679.1275360964578--

------=_Part_13986_26026450.1275360964578--
