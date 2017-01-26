package OpenCloset::Share::Web::Controller::Hook;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON;

use Try::Tiny;

use Iamport::REST::Client;

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 iamport

    POST /webhooks/iamport

=cut

sub iamport {
    my $self = shift;

    my $v = $self->validation;
    $v->required("imp_uid");
    $v->required("merchant_uid");
    $v->required("status");

    my $sid    = $v->param("imp_uid");
    my $cid    = $v->param("merchant_uid");
    my $status = $v->param("status");

    my $payment = $self->schema->resultset("Payment")->find( { sid => $sid } );
    return $self->error( 404, "Not found payment: sid($sid)" ) unless $payment;

    my $payment_id = $payment->id;
    return $self->error( 404, "Not found order: payment_id($payment_id)" ) unless $payment->order;

    my $payment_log = $payment->payment_logs( {}, { order_by => { -desc => "id" } } )->next;
    return $self->error( 404, "Not found payment log: payment_id($payment_id)" ) unless $payment_log;

    ## 가상계좌(vbank)의 ready -> paid
    my $last_status = $payment_log->status;
    if ( $last_status && $last_status eq "ready" && $status eq "paid" ) {
        #
        # FIXME
        #   직접 PG사에 REST API 호출 후 그 결과를 저장해야 함
        #

        my $iamport = $self->config->{iamport};
        my $key     = $iamport->{key};
        my $secret  = $iamport->{secret};
        my $client  = Iamport::REST::Client->new( key => $key, secret => $secret );

        my $json = $iamport->payment($sid);
        unless ($json) {
            $self->log->info("cannot fetch payment information");
            #
            # FIXME : 로그 이후 처리 과정 필요
            #
        }

        my ( $data, $error ) = do {
            try {
                my $d = Mojo::JSON::decode_json($json);
                return ( $d, undef );
            }
            catch {
                chomp;
                return ( undef, $_ );
            }
        }
        unless ($data) {
            $self->log->info("cannot decode json: $error");
            #
            # FIXME : 로그 이후 처리 과정 필요
            #
        }

        unless ($data) {
            $self->log->info("cannot decode json: $error");
            #
            # FIXME : 로그 이후 처리 과정 필요
            #
        }

        my $res = $data->{response};
        unless ($res) {
            $self->log->info("invalid response: $json");
            #
            # FIXME : 로그 이후 처리 과정 필요
            #
        }

        my $str = sprintf(
            "buyer_addr:   %s\n"
            . "buyer_email:  %s\n"
            . "buyer_name:   %s\n"
            . "buyer_name:   %s\n"
            . "buyer_tel:    %s\n"
            . "imp_uid:      %s\n"
            . "merchant_uid: %s\n"
            . "status:       %s\n",
            $data->{response}{buyer_addr},
            $data->{response}{buyer_email},
            $data->{response}{buyer_name},
            $data->{response}{buyer_tel},
            $data->{response}{imp_uid},
            $data->{response}{merchant_uid},
            $data->{response}{status},
        );
        $self->log->debug($str);

        unless ( $sid eq $res->{imp_uid} && $cid eq $res->{merchant_uid} ) {
            $self->log->info("invalid sid: $json");
            #
            # FIXME : 로그 이후 처리 과정 필요
            #
        }

        unless ( $status eq $res->{status} ) {
            $self->log->info("status does not match: $status vs $res->{status}");
            #
            # FIXME : 로그 이후 처리 과정 필요
            #
        }

        $payment->create_related(
            "payment_logs",
            {
                status => $status,
            },
        );
        $self->payment_done( $payment->order );
    }

    $self->render( text => "OK" );
}

1;
