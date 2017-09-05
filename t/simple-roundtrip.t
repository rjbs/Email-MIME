use strict;
use warnings;
use Test::More;
use Encode;

BEGIN {
    plan skip_all => 'Email::Address::XS is required for this test'
      unless eval { require Email::Address::XS };
    plan 'no_plan';
}

BEGIN {
    use_ok('Email::MIME::Encode');
}

ok !$INC{'Email/MIME/Header.pm'}, 'Email::MIME::Header not loaded';

my @emails = ( q[<iwrestled@abear.once>], q[me@domoain.cow],
    q["My Name" <me@domain.cow>] );

foreach my $iter ( 1 .. 2 ) {
    my $txt =
      $iter == 1
      ? 'Email::MIME::Header is not loaded'
      : 'Email::MIME::Header is loaded';

    foreach my $email (@emails) {
        my $roundtrip = Email::MIME::Encode::maybe_mime_encode_header(
            To => $email,
            "utf-8"
        );
        is $roundtrip, $email, "preserve original email when $txt";
    }

    use_ok('Email::MIME::Header') if $iter == 1;

}
