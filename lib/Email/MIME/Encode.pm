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

    return $val
        unless _needs_encode($val);

    $header =~ s/^resent-//i;

    return $encoders{$header}->($val, $charset)
        if exists $encoders{$header};

    return _unstructured_encode($val, $charset);
}

sub _needs_encode {
    my ($val) = @_;
    return defined $val && $val =~ /(?:\P{ASCII}|=\?|[^\s]{79,}|^\s+|\s+$)/s;
}

sub _date_time_encode {
    my ($val, $charset) = @_;
    return $val;
}

sub _mailbox_encode {
    my ($val, $charset) = @_;
    return _mailbox_list_encode($val, $charset);
}

sub _mailbox_list_encode {
    my ($val, $charset) = @_;
    my @addrs = Email::Address->parse($val);

    @addrs = map {
        my $phrase = $_->phrase;
        $_->phrase(mime_encode($phrase, $charset))
            if defined $phrase && $phrase =~ /\P{ASCII}/;
        my $comment = $_->comment;
        $_->comment(mime_encode($comment, $charset))
            if defined $comment && $comment =~ /\P{ASCII}/;
        $_;
    } @addrs;

    return join(', ', map { $_->format } @addrs);
}

sub _address_list_encode {
    my ($val, $charset) = @_;
    return _mailbox_list_encode($val, $charset); # XXX is this right?
}

sub _msg_id_encode {
    my ($val, $charset) = @_;
    return $val;
}

sub _unstructured_encode {
    my ($val, $charset) = @_;
    return mime_encode($val, $charset);
}

# XXX this is copied directly out of Courriel::Header
# eventually, this should be extracted out into something that could be shared
sub mime_encode {
    my $text    = shift;
    my $charset = Encode::find_encoding(shift)->mime_name();

    my $head = '=?' . $charset . '?B?';
    my $tail = '?=';

    my $base_length = 75 - ( length($head) + length($tail) );

    # This code is copied from Mail::Message::Field::Full in the Mail-Box
    # distro.
    my $real_length = int( $base_length / 4 ) * 3;

    my @result;
    my $chunk = q{};
    while ( length( my $chr = substr( $text, 0, 1, '' ) ) ) {
        my $chr = Encode::encode( $charset, $chr, 0 );

        if ( length($chunk) + length($chr) > $real_length ) {
            push @result, $head . MIME::Base64::encode_base64( $chunk, q{} ) . $tail;
            $chunk = q{};
        }

        $chunk .= $chr;
    }

    push @result, $head . MIME::Base64::encode_base64( $chunk, q{} ) . $tail
        if length $chunk;

    return join q{ }, @result;
}

1;
