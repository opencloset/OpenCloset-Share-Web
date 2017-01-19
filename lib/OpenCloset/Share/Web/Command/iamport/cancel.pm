package OpenCloset::Share::Web::Command::iamport::cancel;

use Mojo::Base 'Mojolicious::Command';

use Iamport::REST::Client;
use JSON qw/decode_json/;

use OpenCloset::Schema;

has description => 'Cancel order payment';
has usage       => "Usage: APPLICATION iamport cancel [ORDER-ID]\n";

=encoding utf-8

=head1 NAME

OpenCloset::Share::Web::Command::iamport::cancel - cancel paid order

=head1 SYNOPSIS

    $ MOJO_CONFIG=/path/to/share.conf ./script/share iamport cancel <order_id>

=head1 METHODS

=head2 run

=cut

sub run {
    my ( $self, $order_id ) = @_;

    die $self->usage unless $order_id;

    my $schema = $self->app->schema;
    my $order = $schema->resultset('Order')->find( { id => $order_id } );
    die "Not found order: $order_id" unless $order;

    my $payment = $order->payment_histories( { status => 'paid' } )->next;
    die "Not found paid payment" unless $payment;

    my $iamport = $self->config->{iamport};
    my $key     = $iamport->{key};
    my $secret  = $iamport->{secret};
    my $client  = Iamport::REST::Client->new( key => $key, secret => $secret );

    my $imp_uid      = $payment->sid;
    my $merchant_uid = $payment->cid;

    my $json = $client->payment($imp_uid);
    die "Failed to get payment info: $imp_uid" unless $json;

    my $data       = decode_json($json);
    my $pay_method = $data->{response}{pay_method};

    die "Unknown paid method" unless $pay_method;
    die "Not supported vbank" if $pay_method eq 'vbank'; # 환불계좌를 입력해야 함

    $json = $client->cancel( imp_uid => $imp_uid, merchant_uid => $merchant_uid );
    die "Failed cancel request" unless $json;

    $data = decode_json($json);
    $order->create_related(
        'payment_histories',
        {
            sid        => $imp_uid,
            cid        => $merchant_uid,
            amount     => $data->{response}{cancel_amount},
            status     => $data->{response}{status},
            vendor     => $data->{response}{pg_provider},
            pay_method => $data->{response}{pay_method},
            dump       => $json,
        }
    );
}

1;
