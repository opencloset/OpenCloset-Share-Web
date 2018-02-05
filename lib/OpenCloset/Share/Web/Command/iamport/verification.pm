package OpenCloset::Share::Web::Command::iamport::verification;

use Mojo::Base "Mojolicious::Command";

use Iamport::REST::Client;
use JSON qw/decode_json/;

use OpenCloset::Constants qw/%PAY_METHOD_MAP/;
use OpenCloset::Constants::Status qw/$WAITING_DEPOSIT/;

has description => "Verify payment information";
has usage       => "Usage: APPLICATION iamport verification\n";

=encoding utf-8

=head1 NAME

OpenCloset::Share::Web::Command::iamport::verification - Verify payment information

=head1 SYNOPSIS

    $ MOJO_CONFIG=/path/to/share.conf ./script/share iamport verification

=head1 METHODS

=head2 run

=cut

sub run {
    my $self = shift;
    my $app  = $self->app;

    my $schema  = $app->schema;
    my $config  = $app->config->{iamport};
    my $key     = $config->{key};
    my $secret  = $config->{secret};
    my $iamport = Iamport::REST::Client->new( key => $key, secret => $secret );

    while (1) {
        my $paid = $schema->resultset('PaymentLog')->search_literal(
            "DATE_FORMAT(create_date, '%Y-%m-%d') BETWEEN CURDATE() + INTERVAL -1 HOUR AND CURDATE() AND status = ?",
            qw/paid/
        );

        my %paid;
        while ( my $log = $paid->next ) {
            $paid{ $log->payment_id }++;
        }

        my $ready = $schema->resultset('PaymentLog')->search_literal(
            "DATE_FORMAT(create_date, '%Y-%m-%d') BETWEEN CURDATE() + INTERVAL -1 HOUR AND CURDATE() AND status = ?",
            qw/ready/
        );

        while ( my $log = $ready->next ) {
            ### payment_log 는 쌓는 방식이기 때문에 결제가 되었어도 ready 상태가 존재한다.
            ### 해서 paid 이력이 있으면 무시한다.
            next if $paid{ $log->payment_id };

            $app->log->debug( "Checking payment " . $log->payment_id . " ..." );

            my $payment = $log->payment;
            my $order   = $payment->order;

            ## paid 이력이 없는데 결제대기가 아니면 이것은 이상한 거
            ## 혹은 미납금을 위한 가상계좌일 수 있다.
            if ( $order->status_id != $WAITING_DEPOSIT ) {
                $app->log->info( "Wrong order status_id: expected( $WAITING_DEPOSIT ), got( " . $order->status_id . " )" );
                next;
            }

            ## iamport 에 조회해서 결제완료된 것이라면 로그에 넣고 정상처리
            my $sid  = $payment->sid;
            my $json = $iamport->payment($sid);
            unless ($json) {
                $app->log->info("Failed to get payment info from iamport: sid($sid)");
                next;
            }

            my $info   = decode_json($json);
            my $status = $info->{response}{status};
            next if $status ne 'paid';

            my $order_id = $order->id;
            $app->log->info("Found paid payment: order($order_id)");

            my $pay_method = $info->{response}{pay_method};
            my $pl         = $payment->create_related(
                "payment_logs",
                {
                    status => $status,
                    detail => $json,
                },
            );

            my $pay_with = $order->price_pay_with || '';
            $pay_with .= $PAY_METHOD_MAP{$pay_method};
            $order->update( { price_pay_with => $pay_with } );
            $app->payment_done($order);
            my $payment_id = $payment->id;
            $app->log->info("Update payment($payment_id) successfully: order($order_id)");
            sleep(1);
        }

        sleep( 60 * 60 ); # 1 hour
    }
}

1;
