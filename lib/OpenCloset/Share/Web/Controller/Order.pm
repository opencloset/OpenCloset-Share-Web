package OpenCloset::Share::Web::Controller::Order;
use Mojo::Base 'Mojolicious::Controller';

use OpenCloset::Constants::Category qw/$JACKET $PANTS $SHIRT $SHOES $TIE %PRICE/;
use OpenCloset::Constants::Status qw/$PAYMENT $CHOOSE_CLOTHES/;

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

    my $status_id = $CHOOSE_CLOTHES;
    my $pair = grep { /^($JACKET|$PANTS)$/ } @categories;
    $status_id = $PAYMENT if $pair != 2;

    my $order = $self->schema->resultset('Order')->create( { user_id => $user->id, status_id => $status_id } );

    return $self->error( 500, "Couldn't create a new order" ) unless $order;

    for my $category (@categories) {
        $order->create_related(
            'order_details',
            {
                name        => $category,
                price       => $PRICE{$category},
                final_price => $PRICE{$category},
            }
        );
    }

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

    my @categories;
    my @details = $order->order_details;
    map { push @categories, $_->name } @details;

    ## when you create DateTime object without time zone specified, "floating" time zone is set
    ## first call of set_time_zone change time zone to UTC without conversion
    ## second call of set_time_zone change UTC to $timezone
    my $create_date = $order->create_date;
    $create_date->set_time_zone('UTC');
    $create_date->set_time_zone( $self->config->{timezone} );

    my $title = sprintf( '%s님 %s %s 주문서', $user->name, $create_date->ymd, $create_date->hms );
    $self->stash( categories => \@categories, title => $title );
}

=head2 delete_order

    # order.delete
    DELETE /orders/:order_id

=cut

sub delete_order {
    my $self  = shift;
    my $order = $self->stash('order');

    $order->delete;
    $self->render( json => { message => 'Deleted order successfully' } );
}

1;
