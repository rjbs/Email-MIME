use strict;
use warnings;
use Test::More;
use Encode;

BEGIN {
  plan skip_all => 'Email::Address::XS is required for this test' unless eval { require Email::Address::XS };
}

BEGIN {
  use_ok('Email::MIME');
  use_ok('Email::MIME::Header::AddressList');
}

{
  my $email = Email::MIME->new('To: =?US-ASCII?Q?MIME=3A=3B?=: =?US-ASCII?Q?Winston=3A_Smith?= <winston.smith@recdep.minitrue>, =?US-ASCII?Q?Julia=3A=3B_?= <julia@ficdep.minitrue>' . "\r\n\r\n");
  my $str = $email->header_str('To');
  my $obj = $email->header_as_obj('To');
  my @addr = $obj->addresses();
  my @grps = $obj->groups();
  is($str, '"MIME:;": "Winston: Smith" <winston.smith@recdep.minitrue>, "Julia:; " <julia@ficdep.minitrue>;'); # See that decoded From header string is now quoted, so is unambiguous
  is($addr[0]->phrase, 'Winston: Smith');
  is($addr[0]->address, 'winston.smith@recdep.minitrue');
  is($addr[1]->phrase, 'Julia:; ');
  is($addr[1]->address, 'julia@ficdep.minitrue');
  is($grps[0], 'MIME:;');
  is($grps[1]->[0]->phrase, 'Winston: Smith');
  is($grps[1]->[0]->address, 'winston.smith@recdep.minitrue');
  is($grps[1]->[1]->phrase, 'Julia:; ');
  is($grps[1]->[1]->address, 'julia@ficdep.minitrue');
}

{
  my $julia = Email::Address::XS->new(phrase => 'Julia:; ', address => 'julia@ficdep.minitrue');
  my $winston = Email::Address::XS->new(phrase => 'Winston:; Smith', address => 'winston.smith@recdep.minitrue');
  my $email = Email::MIME->create(
    header_str => [
      Sender => $julia,
      From => [ $winston, $julia ],
      To => Email::MIME::Header::AddressList->new_groups('Group:;Name' => [ $julia, $winston ]),
    ]
  );
  my $sender_header_raw = $email->header_raw('Sender');
  my $from_header_raw = $email->header_raw('From');
  my $to_header_raw = $email->header_raw('To');
  my $sender_header = $email->header_str('Sender');
  my $from_header = $email->header_str('From');
  my $to_header = $email->header_str('To');
  my $sender_addr = $email->header_as_obj('Sender')->first_address();
  my @from_addrs = $email->header_as_obj('From')->addresses();
  my @to_grps = $email->header_as_obj('To')->groups();
  is($sender_header_raw, '=?UTF-8?B?SnVsaWE6OyA=?= <julia@ficdep.minitrue>');
  is($from_header_raw, '=?UTF-8?B?V2luc3Rvbjo7IFNtaXRo?= <winston.smith@recdep.minitrue>, =?UTF-8?B?SnVsaWE6OyA=?= <julia@ficdep.minitrue>');
  is($to_header_raw, '=?UTF-8?B?R3JvdXA6O05hbWU=?=: =?UTF-8?B?SnVsaWE6OyA=?= <julia@ficdep.minitrue>, =?UTF-8?B?V2luc3Rvbjo7IFNtaXRo?= <winston.smith@recdep.minitrue>;');
  is($sender_header, '"Julia:; " <julia@ficdep.minitrue>');
  is($from_header, '"Winston:; Smith" <winston.smith@recdep.minitrue>, "Julia:; " <julia@ficdep.minitrue>');
  is($to_header, '"Group:;Name": "Julia:; " <julia@ficdep.minitrue>, "Winston:; Smith" <winston.smith@recdep.minitrue>;');
  is($sender_addr->phrase, 'Julia:; ');
  is($from_addrs[0]->phrase, 'Winston:; Smith');
  is($from_addrs[1]->phrase, 'Julia:; ');
  is($to_grps[0], 'Group:;Name');
  is($to_grps[1]->[0]->phrase, 'Julia:; ');
  is($to_grps[1]->[1]->phrase, 'Winston:; Smith');

  $email->header_raw_set('Sender', 'Julia <julia@ficdep.minitrue>');
  $sender_header_raw = $email->header_raw('Sender');
  $sender_header = $email->header_str('Sender');
  $sender_addr = $email->header_as_obj('Sender')->first_address();
  is($sender_header_raw, 'Julia <julia@ficdep.minitrue>');
  is($sender_header, 'Julia <julia@ficdep.minitrue>');
  is($sender_addr->phrase, 'Julia');
  is($sender_addr->address, 'julia@ficdep.minitrue');

  $email->header_raw_set('Bcc', '=?UTF-8?B?SnVsaWE6OyA=?= <julia@ficdep.minitrue>');
  my $bcc_header_raw = $email->header_raw('Bcc');
  my $bcc_header = $email->header_str('Bcc');
  my $bcc_addr = $email->header_as_obj('Bcc')->first_address();
  my @bcc_grps = $email->header_as_obj('Bcc')->groups();
  is($bcc_header_raw, '=?UTF-8?B?SnVsaWE6OyA=?= <julia@ficdep.minitrue>');
  is($bcc_header, '"Julia:; " <julia@ficdep.minitrue>');
  is($bcc_addr->phrase, 'Julia:; ');
  is($bcc_addr->address, 'julia@ficdep.minitrue');
  is($bcc_grps[0], undef);
  is($bcc_grps[1]->[0]->phrase, 'Julia:; ');
  is($bcc_grps[1]->[0]->address, 'julia@ficdep.minitrue');

  # Explicit call with object Email::MIME::Header::AddressList
  $email->header_str_set('Bcc', Email::MIME::Header::AddressList->new_groups('Group' => [ $winston ]));
  $bcc_header_raw = $email->header_raw('Bcc');
  $bcc_header = $email->header_str('Bcc');
  $bcc_addr = $email->header_as_obj('Bcc')->first_address();
  @bcc_grps = $email->header_as_obj('Bcc')->groups();
  is($bcc_header_raw, 'Group: =?UTF-8?B?V2luc3Rvbjo7IFNtaXRo?= <winston.smith@recdep.minitrue>;');
  is($bcc_header, 'Group: "Winston:; Smith" <winston.smith@recdep.minitrue>;');
  is($bcc_addr->phrase, 'Winston:; Smith');
  is($bcc_addr->address, 'winston.smith@recdep.minitrue');
  is($bcc_grps[0], 'Group');
  is($bcc_grps[0], 'Group');
  is($bcc_grps[1]->[0]->phrase, 'Winston:; Smith');
  is($bcc_grps[1]->[0]->address, 'winston.smith@recdep.minitrue');

  # Implicit call to Email::MIME::Header::AddressList->from_string($string)
  $email->header_str_set('Cc', '"MIME:;": "Winston: Smith" <winston.smith@recdep.minitrue>;');
  my $cc_header_raw = $email->header_raw('Cc');
  my $cc_header = $email->header_str('Cc');
  my $cc_addr = $email->header_as_obj('Cc')->first_address();
  my @cc_grps = $email->header_as_obj('Cc')->groups();
  is($cc_header_raw, '=?UTF-8?B?TUlNRTo7?=: =?UTF-8?B?V2luc3RvbjogU21pdGg=?= <winston.smith@recdep.minitrue>;');
  is($cc_header, '"MIME:;": "Winston: Smith" <winston.smith@recdep.minitrue>;');
  is($cc_addr->phrase, 'Winston: Smith');
  is($cc_addr->address, 'winston.smith@recdep.minitrue');
  is($cc_grps[0], 'MIME:;');
  is($cc_grps[1]->[0]->phrase, 'Winston: Smith');
  is($cc_grps[1]->[0]->address, 'winston.smith@recdep.minitrue');

  # Implicit stringification of $winston and call to Email::MIME::Header::AddressList->from_string($string)
  $email->header_str_set('Sender', $winston);
  $sender_header_raw = $email->header_raw('Sender');
  $sender_header = $email->header_str('Sender');
  $sender_addr = $email->header_as_obj('Sender')->first_address();
  is($sender_header_raw, '=?UTF-8?B?V2luc3Rvbjo7IFNtaXRo?= <winston.smith@recdep.minitrue>');
  is($sender_header, '"Winston:; Smith" <winston.smith@recdep.minitrue>');
  is($sender_addr->phrase, 'Winston:; Smith');
  is($sender_addr->address, 'winston.smith@recdep.minitrue');

  # Implicit stringification of $winston and $julia and call to Email::MIME::Header::AddressList->from_string($winston, $julia)
  $email->header_str_set('Cc', [ $winston, $julia ]);
  $cc_header_raw = $email->header_raw('Cc');
  $cc_header = $email->header_str('Cc');
  $cc_addr = $email->header_as_obj('Cc')->first_address();
  @cc_grps = $email->header_as_obj('Cc')->groups();
  is($cc_header_raw, '=?UTF-8?B?V2luc3Rvbjo7IFNtaXRo?= <winston.smith@recdep.minitrue>, =?UTF-8?B?SnVsaWE6OyA=?= <julia@ficdep.minitrue>');
  is($cc_header, '"Winston:; Smith" <winston.smith@recdep.minitrue>, "Julia:; " <julia@ficdep.minitrue>');
  is($cc_addr->phrase, 'Winston:; Smith');
  is($cc_addr->address, 'winston.smith@recdep.minitrue');
  is($cc_grps[0], undef);
  is($cc_grps[1]->[0]->phrase, 'Winston:; Smith');
  is($cc_grps[1]->[0]->address, 'winston.smith@recdep.minitrue');
  is($cc_grps[1]->[1]->phrase, 'Julia:; ');
  is($cc_grps[1]->[1]->address, 'julia@ficdep.minitrue');
}

done_testing;
