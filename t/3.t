use Test::More;

if (eval {require Encode}) {
   plan tests => 3;
} else {Test::More->import(skip_all =>"Unicode support not there on this platform"); }
# Header decoding tests.

use Email::MIME;
open IN, "t/Mail/joejob" or die $!;
undef $/;
my $string = <IN>;
my $obj = Email::MIME->new($string);

sub printable ($) {join ("", map {/[\x20-\xff]/i?$_:'\\x'.sprintf("%x",ord$_) } split //, shift) }

is(printable $obj->header("From"), '\\x963f\\x7f8e.. <simon@oreillynet.com>', "Decoded header");
is(printable $obj->header("To"), '\\x8cfa1000\\x5143 <gcatey@hoosierlottery.com>', "Decoded header");
is(printable $obj->header("Subject"),
'15.\\x570b\\x7acb\\x5927\\x5b78\\x5bc4\\x4f86\\x7684??', "Decoded header");
