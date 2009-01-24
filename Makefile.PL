use strict;
use ExtUtils::MakeMaker;

WriteMakefile (
  AUTHOR        => 'Casey West <casey@geeknest.com>',
  ABSTRACT      => "Modify Email::MIME Objects Easily",
  NAME          => 'Email::MIME::Modifier',
  (eval { ExtUtils::MakeMaker->VERSION(6.21) } ? (LICENSE => 'perl') : ()),
  PREREQ_PM     => {
    'Email::MIME'      => '1.82',
    'Email::MessageID' => '1.2',
    'Email::Simple'    => '1.92',
    'Test::More'       => '0.47',
    'Email::MIME::ContentType' => '1.0',
    'Email::MIME::Encodings'   => '1.3',
  },
  VERSION_FROM  => 'lib/Email/MIME/Modifier.pm',
  (eval { ExtUtils::MakeMaker->VERSION(6.46) }
    ? (META_MERGE => {
        resources => {
          Repository => 'http://github.com/rjbs/email-mime-modifier'
        }
      })
    : ()
  ),
);
