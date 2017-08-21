use strict;
use warnings;
use Test::More;
use utf8;

use Encode;

require_ok 'Email::MIME';

subtest "encode_check 0 during create()" => sub {
  my $email = Email::MIME->create(
    attributes => {
      encoding => '8bit',
      charset  => 'us-ascii',
    },
    body_str => "Look, a snowman: ☃",
    encode_check => Encode::FB_DEFAULT,
  );

  ok($email, 'we created an email with badly encoded data');

  is(
    $email->body_str,
    'Look, a snowman: ?',
    'Our non us-ascii char was replaced with a question mark'
  );

  like(
    $email->as_string,
    qr/a snowman: \?/,
    'as_string looks nice'
  );
};

subtest "encode_check 0 during create(), multi-part" => sub {
  my $email = Email::MIME->create(
    parts => [
        q[Totally ascii first part],
        q[Look, a snowman: ☃],
    ],
    encode_check => Encode::FB_DEFAULT,
  );

  ok($email, 'we created an email with badly encoded data');

  my $part_num = 1;

  $email->walk_parts(sub {
    my ($part) = @_;
    return if $part->subparts;

    is(
      $part->encode_check,
      Encode::FB_DEFAULT,
      "subpart picked up email's encode_check setting"
    );
  });
};

subtest "encode_check 0 during new()" => sub {
  my $email = Email::MIME->new(<<'EOF', { encode_check => 0 });
Date: Fri, 16 Jun 2017 09:48:19 -0400
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Transfer-Encoding: quoted-printable

Look, another snowman: =E2=98=83=
EOF

  ok($email, 'we created an email with badly encoded data');
  is(
    $email->body_str,
    'Look, another snowman: ���',
    'Our non us-ascii char was replaced with a question mark'
  );

  like(
    $email->as_string,
    qr/another snowman: =E2=98=83/,
    'as_string unchanged from input...'
  );
};

subtest "encode_check 1 during create()" => sub {
  eval {
    my $email = Email::MIME->create(
      attributes => {
        encoding => '8bit',
        charset  => 'us-ascii',
      },
      body_str => "Look, a snowman: ☃",
      encode_check => Encode::FB_CROAK,
    );
  };

  ok($@, 'encode_check 1 with bad data crashes');
};

subtest "encode_check default during create()" => sub {
  eval {
    my $email = Email::MIME->create(
      attributes => {
        encoding => '8bit',
        charset  => 'us-ascii',
      },
      body_str => "Look, a snowman: ☃",
    );
  };

  ok($@, 'encode_check default with bad data crashes');
};

subtest "encode_check 1 during new()" => sub {
  eval {
    my $email = Email::MIME->new(<<'EOF', { encode_check => 1 });
Date: Fri, 16 Jun 2017 09:48:19 -0400
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Transfer-Encoding: quoted-printable

Look, another snowman: =E2=98=83=
EOF

    # We crash when trying to decode the body
    $email->body_str;
  };

  ok($@, 'encode_check 1 with bad data crashes');
};

subtest "encode_check default during new()" => sub {
  eval {
    my $email = Email::MIME->new(<<'EOF');
Date: Fri, 16 Jun 2017 09:48:19 -0400
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Transfer-Encoding: quoted-printable

Look, another snowman: =E2=98=83=
EOF

    # We crash when trying to decode the body
    $email->body_str;
  };

  ok($@, 'encode_check default with bad data crashes');
};

done_testing;
