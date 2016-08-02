package OpenCloset::Share::Web::Controller::Order;
use Mojo::Base 'Mojolicious::Controller';

use OpenCloset::Constants::Category;
use OpenCloset::Constants::Status qw/$PAYMENT/;

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 add

    # order.add
    GET /orders/new

=cut

sub add {
    my $self = shift;
}

=head2 create

    # order.create
    POST /orders

=cut

sub create {
    my $self = shift;
    my $user = $self->stash('user');

    my @categories;
    for my $c ( $JACKET, $PANTS, $SHIRT, $SHOES, $TIE ) {
        my $p = $self->param("category-$c") || '';
        push @categories, $c if $p eq 'on';
    }

    $self->session( order => { categories => [@categories] } );
    my $order = $self->schema->resultset('Order')->create( { user_id => $user->id, status_id => $PAYMENT } );

    return $self->error( 500, "Couldn't create a new order" ) unless $order;
    $self->redirect_to( 'order.order', order_id => $order->id );
}

=head2 order_id

    under /orders/:order_id

=cut

sub order_id {
    my $self     = shift;
    my $order_id = $self->param('order_id');
    my $order    = $self->schema->resultset('Order')->find( { id => $order_id } );

    return unless $order;

    $self->stash( order => $order );
    return 1;
}

=head2 order

    # order.order
    GET /orders/:order_id

=cut

sub order {
    my $self  = shift;
    my $order = $self->stash('order');
    my $user  = $self->stash('user');

    my $categories = $self->session('order')->{categories};
    my $title = sprintf( '%s님 %s 주문서', $user->name, $order->create_date->ymd );
    $self->stash( categories => $categories, title => $title );
}

1;
