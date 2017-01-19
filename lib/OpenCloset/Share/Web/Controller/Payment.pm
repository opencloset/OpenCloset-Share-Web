package OpenCloset::Share::Web::Controller::Payment;
use Mojo::Base 'Mojolicious::Controller';

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 create_payment

    POST /payments

=cut

sub create_payment {
    my $self = shift;

    my $v = $self->validation;
    $v->required('order_id');
    $v->optional('imp_uid');
    $v->optional('merchant_uid');
    $v->optional('amount')->like(qr/^\d+$/);
    $v->optional('status')->in(qw/paid ready cancelled failed/);
    $v->optional('vendor');
    $v->optional('pg_provider');
    $v->optional('pay_method');
    $v->optional('dump');

    my $order_id   = $v->param('order_id');
    my $sid        = $v->param('imp_uid');
    my $cid        = $v->param('merchant_uid');
    my $amount     = $v->param('amount');
    my $status     = $v->param('status');
    my $vendor     = $v->param('pg_provider');
    my $pay_method = $v->param('pay_method');
    my $dump       = $v->param('dump');

    my $order = $self->schema->resultset('Order')->find( { id => $order_id } );
    return $self->error( 404, "Not found order: $order_id" ) unless $order;

    my $history = $self->schema->resultset('PaymentHistory')->create(
        {
            order_id   => $order_id,
            sid        => $sid,
            cid        => $cid,
            amount     => $amount,
            status     => $status,
            vendor     => $vendor,
            pay_method => $pay_method,
            dump       => $dump,
        }
    );

    return $self->error( 500, "Failed to create a new payment history" ) unless $history;

    if ( $status && $status eq 'paid' ) {
        $self->payment_done($order);
    }

    $self->render( json => { $history->get_columns } );
}

1;
