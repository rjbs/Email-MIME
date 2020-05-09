#!perl
# vim:ft=perl
use strict;
use warnings;

use Test::More;
use Email::MIME;

plan skip_all => "This is more of a helper than a test.";

sub very_deep_email_string {
  my $depth = $_[0] || 250_000;

  my $str = q{};
  my $boundary_prefix = "a" x 77;
  for my $i (1 .. $depth) {
    my $boundary = sprintf "$boundary_prefix%08x", $i;
    $str .= "Content-Type: multipart/mixed; boundary=$boundary\n";
    $str .= "\n";
    $str .= "--$boundary\n\n";
  }

  for my $i (reverse(1 .. $depth)) {
    $str .= sprintf "--${boundary_prefix}%08x--\n\n", $i;
  }

  return $str;
}

sub very_attached_email_string {
  my $parts = $_[0] || 250_000;

  my $str = q{};
  my $boundary_prefix = "a" x 77;
  for my $i (1 .. $parts) {
    my $boundary = sprintf "$boundary_prefix%08x", $i;
    $str .= "Content-Type: text/plain; boundary=$boundary\n";
    $str .= "\n";
    $str .= "--$boundary\n\n";
    $str .= sprintf "--${boundary_prefix}%08x--\n\n", $i;
  }

  return $str;
}

print `ps -o rss -p $$`;

my $VAES = very_attached_email_string;
warn length($VAES) / 1024;
my $email = Email::MIME->new($VAES);

print `ps -o rss -p $$`;

# local $Email::MIME::MAX_DEPTH = 2;

$email = Email::MIME->new( very_deep_email_string() );

print `ps -o rss -p $$`;
