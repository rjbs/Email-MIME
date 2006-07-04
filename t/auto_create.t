use Test::More qw[no_plan];
use strict;
$^W = 1;

use_ok 'Email::MIME::Creator';
use Config;

my $email = Email::MIME->create(
    header => [
      From    => 'me',
      To      => 'you',
      Subject => 'test',
    ],
    parts => [
        q[Part one],
        q[Part two],
        get_perl_exe(),
    ],
);

isa_ok $email, 'Email::MIME';
is scalar($email->parts), 3, 'two parts';

my @parts = $email->parts;

isa_ok $_, 'Email::MIME' for @parts;

like $parts[0]->body, qr/Part one/;
like $parts[1]->body, qr/Part two/;

like $parts[2]->content_type, qr/binary/, 'third part is binary';

sub get_perl_exe {
    open PERL, "< $Config{perlpath}" or die $!;
    my $perl = do { local $/; <PERL> };
    close PERL;
    return $perl;
}
