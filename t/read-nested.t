use strict;
use warnings;

use Test::More tests => 4;
use Email::MIME;

open IN, 't/Mail/nested-parts' or die "Can't read mail";
my $incoming = do { local $/; <IN>; };

my $msg = Email::MIME->new($incoming);
isa_ok($msg => 'Email::MIME');

is(scalar($msg->parts), 1,'outer part');

my @outer_parts = $msg->parts;
is(scalar($outer_parts[0]->parts), 1,'middle part');

my @middle_parts = $outer_parts[0]->parts;
cmp_ok(scalar($middle_parts[0]->parts), '>', 1,'inner part');
