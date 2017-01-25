package OpenCloset::Share::Web::Controller::Hook;
use Mojo::Base 'Mojolicious::Controller';

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
    my $last_status = $payment->status;
    if ( $last_status && $last_status eq "ready" && $status eq "paid" ) {
        #
        # FIXME
        #   직접 PG사에 REST API 호출 후 그 결과를 저장해야 함
        #
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
