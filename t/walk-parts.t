use strict;
use warnings;

use Test::More 0.88;

use Email::MIME;
my $email;
{
  local $/;
  $email = Email::MIME->new(<DATA>);
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
