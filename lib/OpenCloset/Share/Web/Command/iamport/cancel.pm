package OpenCloset::Share::Web::Command::iamport::cancel;

use Mojo::Base "Mojolicious::Command";

use Iamport::REST::Client;
use JSON qw/decode_json/;

use OpenCloset::Schema;

has description => "Cancel order payment";
has usage       => "Usage: APPLICATION iamport cancel <payment_id>\n";

=encoding utf-8

=head1 NAME

OpenCloset::Share::Web::Command::iamport::cancel - cancel payment

=head1 SYNOPSIS

    $ MOJO_CONFIG=/path/to/share.conf ./script/share iamport cancel <payment_id>

=head1 METHODS

=head2 run

=cut

sub run {
    my ( $self, $payment_id ) = @_;

    die $self->usage unless $payment_id;

    my $schema  = $self->app->schema;
    my $payment = $schema->resultset("Payment")->find($payment_id);
    die "Not found payment: $payment_id" unless $payment;

    my $payment_log = $payment->payment_logs( {}, { order_by => { -desc => "id" } } )->next;
    die "Not found payment log" unless $payment_log;
    die "Not paid payment" unless $payment_log->status eq "paid";

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
    die "Not supported vbank" if $pay_method eq "vbank"; # 환불계좌를 입력해야 함

    $json = $client->cancel(
        imp_uid      => $imp_uid,
        merchant_uid => $merchant_uid,
    );
    die "Failed cancel request" unless $json;

    $data = decode_json($json);
    $payment->create_related(
        "payment_logs",
        {
            status => $data->{response}{status},
            detail => $json,
        },
    );
}

1;
