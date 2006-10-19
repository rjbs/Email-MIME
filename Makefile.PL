use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
if ($]< 5.00703) {
    print "Email::MIME requires either Encode or MIME::Words to decode
MIME headers. You've not got Perl 5.7.3, so for you, we depend on 
MIME::Words.\n\n";
}
WriteMakefile(
  'NAME'		=> 'Email::MIME',
  'VERSION_FROM'	=> 'lib/Email/MIME.pm', # finds $VERSION
  'PREREQ_PM'		=> {
    'Email::MIME::ContentType' => '1.011',
    'Email::MIME::Encodings'   => '1.3',
    'Email::Simple' => '1.995',
    'MIME::Types'   => '1.13',
    'Test::More'    => '0.47',
    (
      $] < 5.00703 ? ('MIME::Words' => '5.404' )
                   : ('Encode' => '1.9801')
    ),
  }, # e.g., Module::Name => 1.1
);
