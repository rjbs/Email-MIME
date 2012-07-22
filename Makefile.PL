use 5.8.1; # see t/perl-minver.t
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
  NAME  => 'Email::MIME',
  VERSION_FROM  => 'lib/Email/MIME.pm',
  (eval { ExtUtils::MakeMaker->VERSION(6.21) } ? (LICENSE => 'perl') : ()),
  PREREQ_PM => {
    'Email::Simple' => '2.102', # crlf handling
    'Encode'        => '1.9801',
    'MIME::Types'   => '1.13',
    'Test::More'    => '0.88',
    'Email::MIME::ContentType' => '1.011',
    'Email::MIME::Encodings'   => '1.313',
    'Email::Simple::Creator'   => 0,
    'Email::MessageID',        => 0,
  },
  (eval { ExtUtils::MakeMaker->VERSION(6.46) }
    ? (META_MERGE => {
        resources => {
          repository => 'http://github.com/rjbs/email-mime'
        }
      })
    : ()
  ),
);

