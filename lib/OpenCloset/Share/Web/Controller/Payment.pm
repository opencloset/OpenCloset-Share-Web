package OpenCloset::Share::Web::Controller::Payment;
use Mojo::Base 'Mojolicious::Controller';

use Try::Tiny;

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 payment_id

    under /payments/:payment_id

=cut

sub payment_id {
    my $self       = shift;
    my $payment_id = $self->param("payment_id");
    my $payment    = $self->schema->resultset("Payment")->find( { id => $payment_id } );

    unless ($payment) {
        $self->error( 404, "Payment not found: $payment_id" );
        return;
    }

    my $user      = $self->stash("user");
    my $user_info = $self->stash("user_info");
    if ( $user_info->staff != 1 && $user->id != $payment->order->user_id ) {
        $self->error( 400, "Permission denied" );
        return;
    }

    $self->stash( payment => $payment );
    return 1;
}

=head2 update_payment

    PUT /payments/:payment_id

=cut

sub update_payment {
    my $self    = shift;
    my $payment = $self->stash("payment");

    return $self->error( 400, "Not found order from payment: " . $payment->id ) unless $payment->order;

    #
    # parameter check & fetch
    #
    my $v = $self->validation;
    $v->required("order_id")->in( $payment->order_id );
    $v->required("merchant_uid")->in( $payment->cid );
    $v->optional("amount")->in( $payment->amount );
    $v->optional("pay_method")->in( $payment->pay_method );
    $v->optional("imp_uid");
    $v->optional("pg_provider");
    $v->optional("status")->in(qw/paid ready cancelled failed/);
    $v->optional("detail");
    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, "Parameter validation failed: " . join( ", ", @$failed ) );
    }
    my $sid        = $v->param("imp_uid");
    my $cid        = $v->param("merchant_uid");
    my $amount     = $v->param("amount");
    my $vendor     = $v->param("pg_provider");
    my $pay_method = $v->param("pay_method");
    my $status     = $v->param("status");
    my $detail     = $v->param("detail");

    my ( $payment_log, $error ) = do {
        my $guard = $self->schema->txn_scope_guard;
        try {
            $payment->update(
                {
                    sid    => $sid,
                    vendor => $vendor,
                },
            );

            my $pl = $payment->create_related(
                "payment_logs",
                {
                    status => $status,
                    detail => $detail,
                },
            );

            $guard->commit;

            return ( $pl, undef );
        }
        catch {
            chomp;
            $self->log->error($_);
            return ( undef, $_ );
        };
    };

    return $self->error( 500, "Failed to update the payment & create payment_log" ) unless $payment && $payment_log;
    $self->render( json => { $payment->get_columns } );
}

1;
