use strict;
use warnings;
package Email::MIME::Encode;
# ABSTRACT: a private helper for MIME header encoding

use Email::Address;
use Encode ();
use MIME::Base64();

my %address_list_headers = map { $_ => undef } qw(from sender reply-to to cc bcc);
my %no_mime_headers = map { $_ => undef } qw(date message-id in-reply-to references downgraded-message-id downgraded-in-reply-to downgraded-references);

sub maybe_mime_encode_header {
    my ($header, $val, $charset) = @_;

    $header = lc $header;

    my $header_length = length($header) + length(": ");
    my $min_wrap_length = 78 - $header_length + 1;

    return $val
        unless _needs_encode($val) || $val =~ /[^\s]{$min_wrap_length,}/;

    $header =~ s/^resent-//i;

    return $val
        if exists $no_mime_headers{$header};

    return _address_list_encode($val, $charset)
        if exists $address_list_headers{$header};

    return mime_encode($val, $charset, $header_length);
}

sub _needs_encode {
    my ($val) = @_;
    return defined $val && $val =~ /(?:\P{ASCII}|=\?|[^\s]{79,}|^\s+|\s+$)/s;
}

sub _needs_encode_addr {
    my ($val) = @_;
    return _needs_encode($val) || ( defined $val && $val =~ /[:;,]/ );
}

sub _address_list_encode {
    my ($val, $charset) = @_;
    my @addrs = Email::Address->parse($val);

    foreach (@addrs) {
        my $phrase = $_->phrase;
        # try to not split phrase into more encoded words (hence 0 for header_length)
        # rather fold header around mime encoded word
        $_->phrase(mime_encode($phrase, $charset, 0))
            if _needs_encode_addr($phrase);
        my $comment = $_->comment;
        $_->comment(mime_encode($comment, $charset, 0))
            if _needs_encode_addr($comment);
    }

    return join(', ', map { $_->format } @addrs);
}

# XXX this is copied directly out of Courriel::Header
# eventually, this should be extracted out into something that could be shared
sub mime_encode {
    my ($text, $charset, $header_length) = @_;

    $header_length = 0 unless defined $header_length;

    my $enc_obj = Encode::find_encoding($charset);

    my $head = '=?' . $enc_obj->mime_name() . '?B?';
    my $tail = '?=';

    my $mime_length = length($head) + length($tail);

    # This code is copied from Mail::Message::Field::Full in the Mail-Box
    # distro.
    my $real_length = int( ( 75 - $mime_length ) / 4 ) * 3;
    my $first_length = int( ( 75 - $header_length - $mime_length ) / 4 ) * 3;

    my @result;
    my $chunk = q{};
    my $first_processed = 0;
    while ( length( my $chr = substr( $text, 0, 1, '' ) ) ) {
        my $chr = $enc_obj->encode( $chr, 0 );

        if ( length($chunk) + length($chr) > ( $first_processed ? $real_length : $first_length ) ) {
            if ( length($chunk) > 0 ) {
                push @result, $head . MIME::Base64::encode_base64( $chunk, q{} ) . $tail;
                $chunk = q{};
            }
            $first_processed = 1
                unless $first_processed;
        }

        $chunk .= $chr;
    }

    push @result, $head . MIME::Base64::encode_base64( $chunk, q{} ) . $tail
        if length $chunk;

    return join q{ }, @result;
}

sub maybe_mime_decode_header {
    my ($header, $val) = @_;

    $header = lc $header;
    $header =~ s/^resent-//i;

    return $val
        if exists $no_mime_headers{$header};

    return mime_decode($val);
}

sub mime_decode {
    my ($text) = @_;
    return undef unless defined $text;

    # The eval is to cope with unknown encodings, like Latin-62, or other
    # nonsense that gets put in there by spammers and weirdos
    # -- rjbs, 2014-12-04
    local $@;
    my $result = eval { Encode::decode("MIME-Header", $text) };
    return defined $result ? $result : $text;
}

1;
