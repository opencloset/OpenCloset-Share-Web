package OpenCloset::Share::Web::Controller::Payment;
use Mojo::Base 'Mojolicious::Controller';

use Try::Tiny;
use Mojo::JSON qw/decode_json/;

use OpenCloset::Constants qw/%PAY_METHOD_MAP/;
use OpenCloset::Constants::Status qw/$WAITING_DEPOSIT/;

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
    my $order   = $payment->order;

    return $self->error( 400, "Not found order from payment: " . $payment->id ) unless $order;

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

    my $iamport = $self->app->iamport;
    my $json    = $iamport->payment($sid);
    return $self->error( 500, "Failed to get payment info from iamport: sid($sid)" ) unless $json;

    my $info        = decode_json($json);
    my $info_status = $info->{response}{status};
    my $info_amount = $info->{response}{amount};

    return $self->error( 400, "Payment amount is different: $amount and $info_amount" ) if $amount != $info_amount;
    return $self->error( 400, "Payment status is different: $status and $info_status" ) if $status ne $info_status;

    my ( $payment_log, $error ) = do {
        my $guard = $self->schema->txn_scope_guard;
        try {

            my %params = (
                sid    => $sid,
                vendor => $vendor,
            );
            defined $params{$_} or delete $params{$_} for keys %params;
            $payment->update( \%params );

            my $pl = $payment->create_related(
                "payment_logs",
                {
                    status => $status,
                    detail => $json,
                },
            );

            if ( $info_status eq 'paid' ) {
                my $pay_with = $order->price_pay_with || '';
                $pay_with .= $PAY_METHOD_MAP{$pay_method};
                $order->update( { price_pay_with => $pay_with } );
            }

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

=head2 callback

    GET /payments/:payment_id/callback

모바일결제 callback

=cut

sub callback {
    my $self    = shift;
    my $payment = $self->stash("payment");
    my $order   = $payment->order;

    return $self->error( 400, "Not found order from payment: " . $payment->id ) unless $order;

    my $v = $self->validation;
    $v->required('imp_uid');
    $v->required('merchant_uid');
    $v->required('imp_success');

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, "Parameter validation failed: " . join( ", ", @$failed ) );
    }

    my $sid     = $v->param('imp_uid');
    my $cid     = $v->param('merchant_uid');
    my $success = $v->param('imp_success') || ''; # 'true' or 'false'

    $self->log->info("imp_uid: $sid");
    $self->log->info("merchant_uid: $cid");
    $self->log->info("imp_success: $success");

    my $iamport = $self->app->iamport;
    my $json    = $iamport->payment($sid);
    return $self->error( 500, "Failed to get payment info from iamport" ) unless $json;

    my $info       = decode_json($json);
    my $status     = $info->{response}{status};
    my $amount     = $info->{response}{amount};
    my $pay_method = $payment->pay_method;

    return $self->error( 400, "Payment amount is different." ) if $payment->amount != $amount;

    my ( $payment_log, $error ) = do {
        my $guard = $self->schema->txn_scope_guard;
        try {
            $payment->update( { sid => $sid } );
            my $log = $payment->create_related(
                "payment_logs",
                {
                    status => $status,
                    detail => $json,
                }
            );
            die "Failed to create a Payment log" unless $log;
            if ( $status eq 'ready' && $pay_method eq 'vbank' ) {
                $order->update( { status_id => $WAITING_DEPOSIT } );
            }
            $guard->commit;

            return ( $log, undef );
        }
        catch {
            chomp;
            $self->log->error($_);
            return ( undef, $_ );
        };
    };

    return $self->error( 500, $error ) unless $payment_log;

    if ( $status eq 'paid' ) {
        my $pay_with = $order->price_pay_with || '';
        $pay_with .= $PAY_METHOD_MAP{$pay_method};
        $order->update( { price_pay_with => $pay_with } );
        $self->payment_done($order);
    }
    $self->redirect_to( $self->url_for( 'order.order', { order_id => $order->id } ) );
}

1;
