#!perl -T

use Test::More;
eval "use Test::Pod::Coverage 1.08";
plan skip_all => "Test::Pod::Coverage 1.08 required for testing POD coverage"
  if $@;

# XXX: Determine which of these must be _-ed or documented. -- rjbs, 2006-07-13
my $trustme = [ qw(
  debug_structure
  decode_hook
  fill_parts
  force_decode_hook
  invent_filename
  parts_multipart
  parts_single_part
) ];

all_pod_coverage_ok({
  coverage_class => 'Pod::Coverage::CountParents',
  trustme        => $trustme,
});
