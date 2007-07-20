use ExtUtils::MakeMaker;

# see t/perl-minver.t
use 5.006;

my @encode_deps;
if ($]< 5.00703) {
  print "Email::MIME requires either Encode or MIME::Words to decode
MIME headers. You've not got Perl 5.7.3, so for you, we depend on 
MIME::Words.\n\n";
  push @encode_deps, ('MIME::Words' => '5.404');
} else {
  push @encode_deps, (Encode => '1.9801');
}

WriteMakefile(
  NAME  => 'Email::MIME',
  VERSION_FROM  => 'lib/Email/MIME.pm',
  (eval { ExtUtils::MakeMaker->VERSION(6.21) } ? (LICENSE => 'perl') : ()),
  PREREQ_PM => {
    'Email::MIME::ContentType' => '1.011',
    'Email::MIME::Encodings'   => '1.3',
    'Email::Simple' => '2.003',
    'MIME::Types'   => '1.13',
    'Test::More'    => '0.47',
    @encode_deps,
  },
);
