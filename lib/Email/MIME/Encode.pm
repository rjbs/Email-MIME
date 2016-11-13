use strict;
use warnings;
package Email::MIME::Encode;
# ABSTRACT: a private helper for MIME header encoding

use Email::Address;
use Encode ();
use MIME::Base64();

my %encoders = (
    'date'        => \&_date_time_encode,
    'from'        => \&_mailbox_list_encode,
    'sender'      => \&_mailbox_encode,
    'reply-to'    => \&_address_list_encode,
    'to'          => \&_address_list_encode,
    'cc'          => \&_address_list_encode,
    'bcc'         => \&_address_list_encode,
    'message-id'  => \&_msg_id_encode,
    'in-reply-to' => \&_msg_id_encode,
    'references'  => \&_msg_id_encode,
    'subject'     => \&_unstructured_encode,
    'comments'    => \&_unstructured_encode,
);

sub maybe_mime_encode_header {
    my ($header, $val, $charset) = @_;

    $header = lc $header;

    my $header_length = length($header) + length(": ");
    my $min_wrap_length = 78 - $header_length + 1;

    return $val
        unless _needs_encode($val) || $val =~ /[^\s]{$min_wrap_length,}/;

    $header =~ s/^resent-//i;

    return $encoders{$header}->($val, $charset, $header_length)
        if exists $encoders{$header};

    return _unstructured_encode($val, $charset, $header_length);
}

sub _needs_encode {
    my ($val) = @_;
    return defined $val && $val =~ /(?:\P{ASCII}|=\?|[^\s]{79,}|^\s+|\s+$)/s;
}

sub _date_time_encode {
    my ($val, $charset, $header_length) = @_;
    return $val;
}

sub _mailbox_encode {
    my ($val, $charset, $header_length) = @_;
    return _mailbox_list_encode($val, $charset, $header_length);
}

sub _mailbox_list_encode {
    my ($val, $charset, $header_length) = @_;
    my @addrs = Email::Address->parse($val);

    @addrs = map {
        my $phrase = $_->phrase;
        # try to not split phrase into more encoded words (hence 0 for header_length)
        # rather fold header around mime encoded word
        $_->phrase(mime_encode($phrase, $charset, 0))
            if _needs_encode($phrase);
        my $comment = $_->comment;
        $_->comment(mime_encode($comment, $charset, 0))
            if _needs_encode($comment);
        $_;
    } @addrs;

    return join(', ', map { $_->format } @addrs);
}

sub _address_list_encode {
    my ($val, $charset, $header_length) = @_;
    return _mailbox_list_encode($val, $charset, $header_length); # XXX is this right?
}

sub _msg_id_encode {
    my ($val, $charset, $header_length) = @_;
    return $val;
}

sub _unstructured_encode {
    my ($val, $charset, $header_length) = @_;
    return mime_encode($val, $charset, $header_length);
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

1;
