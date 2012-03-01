use strict;
use warnings;
package Email::MIME::Encode;

use Email::Address;
use Encode ();
use MIME::Base64();

my %encoders = (
    'Date'        => \&_date_time_encode,
    'From'        => \&_mailbox_list_encode,
    'Sender'      => \&_mailbox_encode,
    'Reply-To'    => \&_address_list_encode,
    'To'          => \&_address_list_encode,
    'Cc'          => \&_address_list_encode,
    'Bcc'         => \&_address_list_encode,
    'Message-ID'  => \&_msg_id_encode,
    'In-Reply-To' => \&_msg_id_encode,
    'References'  => \&_msg_id_encode,
    'Subject'     => \&_unstructured_encode,
    'Comments'    => \&_unstructured_encode,
);

sub maybe_mime_encode_header {
    my ($header, $val, $charset) = @_;

    return $val if $val =~ /\p{ASCII}/
                && $val !~ /=\?/;

    $header =~ s/^Resent-//;

    return $encoders{$header}->($val, $charset)
        if exists $encoders{$header};

    return _unstructured_encode($val, $charset);
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
            if $phrase =~ /\P{ASCII}/;
        my $comment = $_->comment;
        $_->comment(mime_encode($comment, $charset))
            if $comment =~ /\P{ASCII}/;
    } @addrs;

    return join(', ', map { $_->format } @addrs);
}

sub _address_encode {
    my ($val, $charset) = @_;
    return _address_list_encode($val, $charset);
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
