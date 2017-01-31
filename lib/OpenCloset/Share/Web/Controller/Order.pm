package OpenCloset::Share::Web::Controller::Order;
use Mojo::Base 'Mojolicious::Controller';

use Data::Pageset;
use Encode qw/encode_utf8/;
use JSON qw/decode_json/;

use OpenCloset::Constants::Category qw/$JACKET $PANTS $SHIRT $SHOES $BELT $TIE $SKIRT $BLOUSE %PRICE/;
use OpenCloset::Constants::Status
    qw/$RETURNED $PARTIAL_RETURNED $PAYMENT $CHOOSE_CLOTHES $CHOOSE_ADDRESS $PAYMENT_DONE $WAITING_SHIPPED $SHIPPED $WAITING_DEPOSIT/;

has schema => sub { shift->app->schema };

our $SHIPPING_FEE = 3000;

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
    my $self      = shift;
    my $user      = $self->stash('user');
    my $user_info = $self->stash('user_info');

    my $v = $self->validation;
    $v->required('wearon_date')->like(qr/^\d{4}-\d{2}-\d{2}$/);
    $v->optional("category-$_") for ( $JACKET, $PANTS, $SHIRT, $SHOES, $BELT, $TIE, $SKIRT, $BLOUSE );
    $v->optional('shirt-type');
    $v->optional('blouse-type');
    $v->optional('pre_color')->in(qw/staff dark black navy charcoalgray gray brown/);

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter validation failed: ' . join( ', ', @$failed ) );
    }

    my @categories;
    for my $c ( $JACKET, $PANTS, $SHIRT, $SHOES, $BELT, $TIE, $SKIRT, $BLOUSE ) {
        my $p = $v->param("category-$c") || '';
        push @categories, $c if $p eq 'on';
    }

    my $wearon_date = $v->param('wearon_date');
    my $status_id   = $CHOOSE_CLOTHES;
    my $pair        = grep { /^($JACKET|$PANTS)$/ } @categories;
    $status_id = $CHOOSE_ADDRESS if $pair != 2;

    my $guard = $self->schema->txn_scope_guard;
    my $param = {
        user_id     => $user->id,
        status_id   => $status_id,
        wearon_date => $wearon_date,
        pre_color   => $v->param('pre_color'),
    };
    map { $param->{$_} = $user_info->$_ } qw/height weight neck bust waist hip topbelly belly thigh arm leg knee foot pants skirt/;
    my $order = $self->schema->resultset('Order')->create($param);

    return $self->error( 500, "Couldn't create a new order" ) unless $order;

    for my $category (@categories) {
        my $desc;
        $desc = $v->param('shirt-type')  if $category eq $SHIRT;
        $desc = $v->param('blouse-type') if $category eq $BLOUSE;
        $order->create_related(
            'order_details',
            {
                name        => $category,
                price       => $PRICE{$category},
                final_price => $PRICE{$category},
                desc        => $desc,
            }
        );
    }

    $order->create_related(
        'order_details',
        {
            name        => '배송비',
            price       => $SHIPPING_FEE,
            final_price => $SHIPPING_FEE,
        }
    );

    $guard->commit;

    $self->redirect_to( 'order.order', order_id => $order->id );
}

=head2 list

    # order.list
    GET /orders?s=19

=cut

sub list {
    my $self = shift;

    return unless $self->admin_auth;

    my $p = $self->param('p') || 1;
    my $s = $self->param('s') || $PAYMENT_DONE;
    my $q = $self->param('q');

    ## TODO: $q 처리
    my $cond = { status_id => $s };
    my $attr = {
        page     => $p,
        rows     => 20,
        order_by => { -desc => 'update_date' },
    };

    my $rs      = $self->schema->resultset('OrderParcel')->search( $cond, $attr );
    my $pager   = $rs->pager;
    my $pageset = Data::Pageset->new(
        {
            total_entries    => $pager->total_entries,
            entries_per_page => $pager->entries_per_page,
            pages_per_set    => 5,
            current_page     => $p,
        }
    );

    $self->render( parcels => $rs, pageset => $pageset );
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

    my $user      = $self->stash('user');
    my $user_info = $self->stash('user_info');
    if ( $user_info->staff != 1 && $user->id != $order->user_id ) {
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

    my $create_date = $order->create_date;
    $self->timezone($create_date);

    my $title = sprintf( '%s님 %s %s 주문서', $user->name, $create_date->ymd, $create_date->hms );
    $self->stash( title => $title );

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
        ## 의류착용일이 +3d 의 조건을 만족하는지 확인
        my $fine        = 1;
        my $now         = $self->timezone( DateTime->now )->truncate( to => 'day' )->epoch;
        my $wearon_date = $self->timezone( $order->wearon_date )->truncate( to => 'day' )->epoch;
        if ( $wearon_date - $now < 60 * 60 * 24 * 3 ) {
            $self->log->info("Not enough wearon_date: +3d");
            $fine = 0;
        }

        $self->render(
            template         => 'order/order.payment',
            user_address     => $order->user_address,
            fine_wearon_date => $fine,
        );
    }
    elsif ( $status_id == $WAITING_DEPOSIT ) {
        my $payment_log = $order->payments->search_related( 'payment_logs', { status => 'ready' }, { rows => 1 } )->single;
        my $payment = $payment_log->payment;

        my $detail = $payment_log->detail;
        return $self->error( 404, "Not found payment info" ) unless $detail;

        my $payment_info = decode_json( encode_utf8($detail) );
        $self->render(
            template     => 'order/order.waiting_deposit',
            payment_info => $payment_info
        );
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
    $v->optional('wearon_date');
    $v->optional('rental_date');
    $v->optional('target_date');

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter validation failed: ' . join( ', ', @$failed ) );
    }

    my $input = $v->input;
    map { delete $input->{$_} } qw/name pk value/; # delete x-editable params

    if ( exists $input->{user_address} ) {
        my $user_address = delete $input->{user_address};
        $input->{user_address_id} = $user_address || undef; # 0 이면 기본주소 사용을 위해 NULL
    }

    if ( exists $input->{status_id} ) {
        my $status_id = delete $input->{status_id};
        if ( $status_id == $PAYMENT_DONE ) {
            ## 결제대기 -> 결제완료
            $self->payment_done($order);
        }
        elsif ( $status_id == $WAITING_SHIPPED ) {
            ## 결제완료 -> 발송대기
            my $clothes_code = $self->every_param('clothes_code');
            delete $input->{clothes_code};
            $self->waiting_shipped( $order, $clothes_code );
        }
        elsif ( $status_id == $RETURNED || $status_id == $PARTIAL_RETURNED ) {
            my $clothes_code = $self->every_param('clothes_code');
            delete $input->{clothes_code};
            if ( $status_id == $RETURNED ) {
                ## xxx -> 전체반납
                $self->returned($order);
            }
            else {
                ## xxx -> 부분반납
                $self->partial_returned( $order, $clothes_code );
            }
        }
        else {
            $input->{status_id} = $status_id;
        }
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
    $self->render( json => { $order->get_columns } );
}

=head2 delete_order

    # order.delete
    DELETE /orders/:order_id

=cut

sub delete_order {
    my $self  = shift;
    my $order = $self->stash('order');

    my @status_can_be_delete = ( $PAYMENT, $CHOOSE_CLOTHES, $CHOOSE_ADDRESS );

    my $status_id = $order->status_id;
    return $self->error( 400, "Couldn't delete status($status_id) order" ) unless "@status_can_be_delete" =~ m/\b$status_id\b/;

    $order->delete;
    $self->render( json => { message => 'Deleted order successfully' } );
}

=head2 purchase

    # order.purchase
    GET /orders/:order_id/purchase

=cut

sub purchase {
    my $self   = shift;
    my $order  = $self->stash('order');
    my $parcel = $order->order_parcel;

    my $status_id = $order->status_id;
    if ( $status_id == $PAYMENT_DONE ) {
        my @staff;
        my @users = $self->schema->resultset('User')->search( { 'user_info.staff' => 1 }, { join => 'user_info' } );
        push @staff, { value => $_->id, text => $_->name } for @users;
        $self->stash( staff => \@staff );
        $self->render( template => 'order/purchase.payment_done' );
    }
    else {
        $self->render( template => 'order/purchase', parcel => $parcel );
    }
}

=head2 update_parcel

    # order.update_parcel
    PUT  /orders/:order_id/parcel
    POST /orders/:order_id/parcel

=cut

sub update_parcel {
    my $self   = shift;
    my $order  = $self->stash('order');
    my $parcel = $order->order_parcel;

    my $v = $self->validation;
    $v->optional('parcel-service');
    $v->optional('waybill')->like(qr/^\d+$/);
    $v->optional('comment');

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter Validation Failed: ' . join( ', ', @$failed ) );
    }

    my $input = $v->input;
    if ( defined $input->{'parcel-service'} ) {
        $input->{parcel_service} = delete $input->{'parcel-service'};
    }

    my $waybill = $parcel->waybill;
    if ( !$waybill && $input->{waybill} ) {
        ## 운송장이 입력되면 배송중으로 변경한다
        $self->update_parcel_status( $order, $SHIPPED );
    }

    $parcel->update($input);
    $self->respond_to(
        html => sub    { shift->redirect_to('order.purchase') },
        json => { json => { $parcel->get_columns } }
    );
}

=head2 create_payment

    POST /order/:id/payments

=cut

sub create_payment {
    my $self  = shift;
    my $order = $self->stash("order");

    #
    # parameter check & fetch
    #
    my $v = $self->validation;
    $v->required("pay_method")->in(qw/ card trans vbank phone /);
    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, "Parameter validation failed: " . join( ", ", @$failed ) );
    }
    my $pay_method = $v->param("pay_method");

    my $amount  = $self->category_price($order);
    my $iamport = $self->config->{iamport};
    my $key     = $iamport->{key};
    my $secret  = $iamport->{secret};
    my $client  = Iamport::REST::Client->new( key => $key, secret => $secret );

    my $merchant_uid = $self->merchant_uid( "share-%d-", $order->id );
    my $json = $client->create_prepare( $merchant_uid, $amount );
    return $self->error( 500, "The payment agency failed to process" ) unless $json;

    my $payment = $order->create_related(
        "payments",
        {
            cid        => $merchant_uid,
            amount     => $amount,
            pay_method => $pay_method,
        },
    );

    return $self->error( 500, "Failed to create a new payment" ) unless $payment;
    $self->render( json => { $payment->get_columns } );
}

1;
