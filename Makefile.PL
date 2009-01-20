use ExtUtils::MakeMaker;

WriteMakefile (
  AUTHOR        => 'Ricardo SIGNES <rjbs@cpan.org>',
  ABSTRACT      => "Email::MIME constructor for starting anew",
  NAME          => 'Email::MIME::Creator',
  (eval { ExtUtils::MakeMaker->VERSION(6.21) } ? (LICENSE => 'perl') : ()),
  PREREQ_PM     => {
    'Email::MIME'            => '1.82',
    'Email::MIME::Modifier'  => '1.440', # allow forced multipart
    'Email::Simple'          => '1.92',
    'Email::Simple::Creator' => '1.4',
    'Test::More'             => '0.47',
  },
  VERSION_FROM  => 'lib/Email/MIME/Creator.pm',
  (eval { ExtUtils::MakeMaker->VERSION(6.46) }
    ? (META_MERGE => {
        resources => {
          Repository => 'http://github.com/rjbs/email-mime-creator'
        }
      })
    : ()
  ),
);
