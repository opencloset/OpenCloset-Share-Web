package OpenCloset::Share::Web::Controller::Order;
use Mojo::Base 'Mojolicious::Controller';

use Data::Pageset;

use OpenCloset::Constants::Category qw/$JACKET $PANTS $SHIRT $SHOES $TIE %PRICE/;
use OpenCloset::Constants::Status qw/$PAYMENT $CHOOSE_CLOTHES $CHOOSE_ADDRESS $PAYMENT_DONE/;

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

=head2 list

    # order.list
    GET /orders?s=19

=cut

sub list {
    my $self = shift;

    return $self->error( 400, "Permission denied" ) unless $self->admin_auth;

    my $p = $self->param('p') || 1;
    my $s = $self->param('s') || $PAYMENT_DONE;
    my $q = $self->param('q');

    ## TODO: $q 처리
    my $cond = { status_id => $s };
    my $attr = { page => $p, rows => 20, order_by => { -desc => 'update_date' } };

    my $rs      = $self->schema->resultset('Order')->search( $cond, $attr );
    my $pager   = $rs->pager;
    my $pageset = Data::Pageset->new(
        {
            total_entries    => $pager->total_entries,
            entries_per_page => $pager->entries_per_page,
            pages_per_set    => 5,
            current_page     => $p,
        }
    );

    $self->render( orders => $rs, pageset => $pageset );
}

=head2 order_id

    under /orders/:order_id

=cut

sub order_id {
    my $self     = shift;
    my $order_id = $self->param('order_id');
    my $order    = $self->schema->resultset('Order')->find( { id => $order_id } );

    unless ($order) {
        $self->error( 404, "Order not found: $order_id" );
        return;
    }

    my $user = $self->stash('user');
    if ( $user->id != $order->user_id ) {
        $self->error( 400, "Permission denied" );
        return;
    }

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

    my $create_date = $order->create_date;
    $self->timezone($create_date);

    my $title = sprintf( '%s님 %s %s 주문서', $user->name, $create_date->ymd, $create_date->hms );
    $self->stash( categories => \@categories, title => $title );

    my $status_id = $order->status_id;
    if ( $status_id == $CHOOSE_CLOTHES ) {
        $self->render( template => 'order/order.choose_clothes' );
    }
    elsif ( $status_id == $CHOOSE_ADDRESS ) {
        $self->render(
            addresses => scalar $user->user_addresses,
            template  => 'order/order.choose_address',
        );
    }
    elsif ( $status_id == $PAYMENT ) {
        my $user_address = $order->user_address;
        $self->render( template => 'order/order.payment', user_address => $user_address );
    }
    else {
        ## 결제완료, 입금확인, 발송대기, 배송중, 배송완료, 반송신청, 반납 등등
        $self->render( template => 'order/order.misc' );
    }
}

=head2 update_order

    # order.update
    PUT /orders/:order_id

=cut

sub update_order {
    my $self  = shift;
    my $order = $self->stash('order');

    my $v = $self->validation;
    $v->optional('status_id')->in(@OpenCloset::Constants::Status::ALL);
    $v->optional('user_address');
    $v->optional('clothes_code');

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter validation failed: ' . join( ', ', @$failed ) );
    }

    my $input = $v->input;
    if ( exists $input->{user_address} ) {
        my $user_address = delete $input->{user_address};
        $input->{user_address_id} = $user_address || undef; # 0 이면 기본주소 사용을 위해 NULL
    }

    if ( exists $input->{status_id} ) {
        my $status_id = $input->{status_id};
        $self->payment_done($order) if $status_id == $PAYMENT_DONE; # 결제대기 -> 결제완료
    }

    if ( my $code = delete $input->{clothes_code} ) {
        my $detail = $order->order_details( { name => $JACKET } )->next;
        if ($detail) {
            $detail->update( { clothes_code => sprintf( '%05s', $code ) } );
        }
        else {
            $self->log->info("Not found clothes_code: $code");
        }
    }

    $order->update($input);
    $self->render( json => { $order->get_columns }, status => 201 );
}

=head2 delete_order

    # order.delete
    DELETE /orders/:order_id

=cut

sub delete_order {
    my $self  = shift;
    my $order = $self->stash('order');

    ## TODO
    ## 주문서의 상태에 따라서 삭제해야합니다.
    ## 대여중인 주문서를 함부러 막 삭제하면 안됩니다.

    $order->delete;
    $self->render( json => { message => 'Deleted order successfully' } );
}

1;
