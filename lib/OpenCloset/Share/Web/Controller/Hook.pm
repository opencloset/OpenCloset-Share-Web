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
    $v->required('imp_uid');
    $v->required('merchant_uid');
    $v->required('status');

    my $sid    = $v->param('imp_uid');
    my $cid    = $v->param('merchant_uid');
    my $status = $v->param('status');

    my $history = $self->schema->resultset('PaymentHistory')->search( { sid => $sid, cid => $cid }, { rows => 1 } )->single;

    return $self->error( 404, "Not found payment history" ) unless $history;

    my $order_id = $history->order_id;
    return $self->error( 404, "Not found order" ) unless $order_id;

    my $order = $self->schema->resultset('Order')->find( { id => $order_id } );
    return $self->error( 404, "Not found order: $order_id" ) unless $order;

    ## 가상계좌(vbank)의 ready -> paid
    my $lstatus = $history->status;
    if ( $lstatus && $lstatus eq 'ready' && $status eq 'paid' ) {
        my %columns = $history->get_columns;
        $columns{status} = $status;
        delete $columns{id};
        delete $columns{dump};
        delete $columns{create_date};
        $self->schema->resultset('PaymentHistory')->create( \%columns );
        $self->payment_done($order);
    }

    $self->render( text => 'OK' );
}

1;
