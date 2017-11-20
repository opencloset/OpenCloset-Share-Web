package OpenCloset::Share::Web::Controller::Order;
use Mojo::Base 'Mojolicious::Controller';

use Data::Pageset;
use DateTime::Format::Strptime;
use DateTime;
use Encode qw/encode_utf8/;
use JSON qw/decode_json/;
use Try::Tiny;

use OpenCloset::Constants qw/$DEFAULT_RENTAL_PERIOD/;
use OpenCloset::Constants::Measurement qw/%AVG_LEG_BY_HEIGHT %AVG_KNEE_BY_HEIGHT/;
use OpenCloset::Constants::Category qw/$JACKET $PANTS $SHIRT $SHOES $BELT $TIE $SKIRT $BLOUSE %PRICE/;
use OpenCloset::Constants::Status
    qw/$RENTAL $RETURNED $PARTIAL_RETURNED $PAYMENT $CHOOSE_CLOTHES $CHOOSE_ADDRESS $PAYMENT_DONE $WAITING_SHIPPED $SHIPPED $DELIVERED $WAITING_DEPOSIT $PAYBACK/;
use OpenCloset::Size::Guess;

has schema => sub { shift->app->schema };

our $SHIPPING_FEE = 3_000;

=head1 METHODS

=head2 add

    # order.add
    GET /orders/new

=cut

sub add {
    my $self      = shift;
    my $user      = $self->stash('user');
    my $user_info = $self->stash('user_info');

    my $shipping_date = $self->date_calc;
    my $dates = $self->date_calc( { shipping => $shipping_date } );

    my $failed = $self->check_measurement( $user, $user_info );
    return $self->error( 400, "대여에 필요한 정보를 입력하지 않았습니다." ) if $failed;

    my $orders = $self->recent_orders($user);
    $self->render( dates => $dates, recent_orders => $orders );
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
    $v->required('additional_day')->like(qr/^\d+$/);
    $v->optional("category-$_") for ( $JACKET, $PANTS, $SHIRT, $SHOES, $BELT, $TIE, $SKIRT, $BLOUSE );
    $v->optional('shirt-type');
    $v->optional('blouse-type');
    $v->optional('pre_color')->in(qw/staff dark black navy charcoalgray gray brown/);
    $v->optional('purpose');
    $v->optional('past-order');

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter validation failed: ' . join( ', ', @$failed ) );
    }

    my $wearon_date   = $v->param('wearon_date');
    my $tz            = $self->config->{timezone};
    my $strp          = DateTime::Format::Strptime->new( pattern => '%F', time_zone => $tz, on_error => 'croak' );
    my $dt_wearon     = $strp->parse_datetime($wearon_date);
    my $dt_max_wearon = DateTime->today( time_zone => $self->config->{timezone} )->add( months => 1 );

    if ( $dt_wearon->epoch > $dt_max_wearon->epoch ) {
        return $self->error( 400, "wearon_date is valid up to +1m: $wearon_date" );
    }

    my @categories;
    for my $c ( $JACKET, $PANTS, $SHIRT, $SHOES, $BELT, $TIE, $SKIRT, $BLOUSE ) {
        my $p = $v->param("category-$c") || '';
        push @categories, $c if $p eq 'on';
    }

    my $status_id = $CHOOSE_CLOTHES;
    my $pair = grep { /^($JACKET|$PANTS)$/ } @categories;
    $status_id = $CHOOSE_ADDRESS if $pair != 2;

    my $additional_day = $v->param('additional_day');
    my $dates = $self->date_calc( { wearon => $dt_wearon }, $additional_day + $DEFAULT_RENTAL_PERIOD );

    my $misc;
    if ( my $order_id = $v->param('past-order') ) {
        my $past_order = $self->schema->resultset('Order')->find( { id => $order_id } );
        if ( $past_order && $past_order->rental_date ) {
            $misc = sprintf( "%s 대여했던 의류를 다시 대여하고 싶습니다.", $past_order->rental_date->ymd );
        }
    }

    my ( $order, $error ) = try {
        my $guard = $self->schema->txn_scope_guard;
        my $param = {
            online           => 1,
            user_id          => $user->id,
            status_id        => $status_id,
            wearon_date      => $wearon_date,
            target_date      => $dates->{target}->datetime(),
            user_target_date => $dates->{target}->datetime(),
            pre_color        => join( ',', @{ $v->every_param('pre_color') } ),
            purpose          => $v->param('purpose'),
            additional_day   => $additional_day,
            misc             => $misc,
        };
        map { $param->{$_} = $user_info->$_ } qw/height weight neck bust waist hip topbelly belly thigh arm leg knee foot pants skirt/;
        my $order = $self->schema->resultset('Order')->create($param);

        return $self->error( 500, "Couldn't create a new order" ) unless $order;

        my $sum = 0;
        my @details;
        for my $category (@categories) {
            my $desc;
            $desc = $v->param('shirt-type')  if $category eq $SHIRT;
            $desc = $v->param('blouse-type') if $category eq $BLOUSE;
            $sum += $PRICE{$category};
            my $detail = $order->create_related(
                'order_details',
                {
                    name        => $category,
                    price       => $PRICE{$category},
                    final_price => $PRICE{$category},
                    desc        => $desc,
                }
            );

            push @details, {
                clothes_category => $category,
                price            => $detail->price,
                final_price      => $detail->final_price,
            };
        }

        $order->create_related(
            'order_details',
            {
                name        => '배송비',
                price       => $SHIPPING_FEE,
                final_price => $SHIPPING_FEE,
                desc        => 'additional',
            }
        );

        my $discount = $order->sale_multi_times_rental( \@details );
        if ( my $price = $discount->{after} - $discount->{before} ) {
            $order->create_related(
                'order_details',
                {
                    name        => "3회 이상 대여 할인",
                    price       => $price,
                    final_price => $price,
                    desc        => 'additional',
                }
            );

            ## 할인된 금액을 기준으로 연장비를 책정
            $sum += $price;
        }

        if ($additional_day) {
            my $extension_fee = $sum * 0.2 * $additional_day;
            $order->create_related(
                'order_details',
                {
                    name  => sprintf( "%d박%d일 +%d일 연장(+%d%%)", 3 + $additional_day, 3 + $additional_day + 1, $additional_day, 20 * $additional_day ),
                    price => $extension_fee,
                    final_price => $extension_fee,
                    desc        => 'additional',
                }
            );
        }

        $guard->commit;
        return $order;
    }
    catch {
        chomp;
        $self->log->error($_);
        return ( undef, $_ );
    };

    return $self->error( 500, $error ) unless $order;
    $self->redirect_to( 'order.order', order_id => $order->id );
}

=head2 list

    GET /orders

=cut

sub list {
    my $self      = shift;
    my $user      = $self->stash('user');
    my $user_info = $self->stash('user_info');

    my $orders = $self->schema->resultset('Order')->search( { user_id => $user->id }, { order_by => { -desc => 'id' } } );
    $self->render( orders => $orders );
}

=head2 shipping_list

    GET /orders/shipping?s=19

=cut

sub shipping_list {
    my $self = shift;

    return unless $self->admin_auth;

    my $p = $self->param('p') || 1;
    my $s = $self->param('s') || $PAYMENT_DONE;
    my $w = $self->param('wearon_date');

    my $cond = {
        online            => 1,
        'me.wearon_date'  => { '!=' => undef },
        'order_parcel.id' => { '!=' => undef },
    };

    $cond->{'me.wearon_date'} = $w if $w;

    ## 배송상태(배송중 or 배송완료) -> 주문서상태(대여중)
    if ( $s == $WAITING_SHIPPED or $s == $SHIPPED or $s == $DELIVERED ) {
        $cond->{'order_parcel.status_id'} = $s;
        $cond->{'me.status_id'}           = $RENTAL;
    }
    else {
        $cond->{'me.status_id'} = $s;
    }

    my $order_by = $s == $RETURNED ? { -desc => 'me.wearon_date' } : { -asc => 'me.wearon_date' };
    my $attr = {
        page     => $p,
        rows     => 20,
        join     => 'order_parcel',
        order_by => $order_by,
    };

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

    my $today = DateTime->today( time_zone => $self->config->{timezone} );
    $self->render( orders => $rs, pageset => $pageset, today => $today );
}

=head2 dates

    GET /orders/dates?wearon_date=yyyy-mm-dd

=cut

sub dates {
    my $self = shift;

    my $v = $self->validation;
    $v->optional('wearon_date')->like(qr/^\d{4}-\d{2}-\d{2}$/);
    $v->optional('days')->like(qr/^\d+$/);

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter validation failed: ' . join( ', ', @$failed ) );
    }

    my $wearon_date = $v->param('wearon_date');
    my $days = $v->param('days') || 0;
    $days += $DEFAULT_RENTAL_PERIOD;
    if ($wearon_date) {
        my $tz    = $self->config->{timezone};
        my $strp  = DateTime::Format::Strptime->new( pattern => '%F', time_zone => $tz, on_error => 'croak' );
        my $dt    = $strp->parse_datetime($wearon_date);
        my $dates = $self->date_calc( { wearon => $dt }, $days );
        map { $dates->{$_} = $dates->{$_}->ymd } keys %$dates;
        $self->render( json => $dates );
    }
    else {
        my $shipping_date = $self->date_calc;
        my $dates = $self->date_calc( { shipping => $shipping_date } );
        $self->render( json => { wearon_date => $dates->{wearon}->ymd } );
    }
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

    my $deadline = $self->payment_deadline($order);
    my $dates = $self->date_calc( { wearon => $order->wearon_date }, $order->additional_day + $DEFAULT_RENTAL_PERIOD );
    $self->stash( order => $order, deadline => $deadline, dates => $dates );
    return 1;
}

=head2 order

    # order.order
    GET /orders/:order_id

=cut

sub order {
    my $self  = shift;
    my $order = $self->stash('order');
    my $user  = $order->user;

    my $create_date = $order->create_date;

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
        $self->render(
            template     => 'order/order.payment',
            user_address => $order->user_address,
        );
    }
    elsif ( $status_id == $WAITING_DEPOSIT ) {
        my $payment_log = $order->payments->search_related( 'payment_logs', { status => 'ready' }, { rows => 1 } )->single;
        return $self->error( 404, "Not found ready status payment log" ) unless $payment_log;

        my $payment = $payment_log->payment;

        my $detail = $payment_log->detail;
        return $self->error( 404, "Not found payment info" ) unless $detail;

        my $payment_info = decode_json( encode_utf8($detail) );
        my $epoch        = $payment_info->{response}{vbank_date};

        unless ($epoch) {
            $self->log->error("Wrong payment info: $detail");
            return $self->error( 500, "Couldn't find vbank due date." );
        }

        my $tz = $self->config->{timezone};
        my $payment_due = DateTime->from_epoch( epoch => $epoch, time_zone => $tz );

        $self->render(
            template     => 'order/order.waiting_deposit',
            payment_info => $payment_info,
            payment_due  => $payment_due
        );
    }
    elsif ( $status_id == $PAYMENT_DONE ) {
        my $dates = $self->stash('dates');
        $self->render(
            template       => 'order/order.payment_done',
            cancel_payment => $self->_cancel_payment_cond( $order, $dates->{shipping} ),
        );
    }
    else {
        ## 입금확인, 발송대기, 배송중, 배송완료, 반송신청, 반납 등등
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
    $v->optional('target_date');
    $v->optional('shipping_misc');
    $v->optional('desc');

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
        elsif ( $status_id == $WAITING_DEPOSIT ) {
            $self->waiting_deposit($order);
        }
        else {
            $input->{status_id} = $status_id;
        }
    }

    if ( defined $input->{clothes_code} ) {
        if ( my $code = delete $input->{clothes_code} ) {
            my $clothes = $self->schema->resultset('Clothes')->find( { code => $code } );
            unless ($clothes) {
                $self->log->warn("Not found clothes code: $code");
            }
            else {
                my $detail = $order->order_details( { name => $JACKET } )->next;
                if ($detail) {
                    $detail->update( { clothes_code => sprintf( '%05s', $code ) } );
                }
                else {
                    $self->log->info("Not found clothes_code: $code");
                }

                if ( my $bottom = $clothes->bottom ) {
                    my $category = $bottom->category;
                    my $detail = $order->order_details( { name => $category } )->next;
                    if ($detail) {
                        $detail->update( { clothes_code => sprintf( '%05s', $bottom->code ) } );
                    }
                    else {
                        $self->log->info( "Not found clothes_code: " . $bottom->code );
                    }
                }
                else {
                    $self->log->warn("Not found bottom: $code");
                }
            }
        }
        else {
            $order->order_details->update_all( { clothes_code => undef } );
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
    $self->flash( message => '주문서가 삭제되었습니다.' );
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

        my $user       = $order->user;
        my $user_info  = $user->user_info;
        my $gender     = $user_info->gender;
        my $height     = $user_info->height;
        my $guess_info = {};

        if ( $gender eq 'male' ) {
            my $leg = $AVG_LEG_BY_HEIGHT{$height};
            unless ( $guess_info->{leg} = $leg ) {
                my $guess = OpenCloset::Size::Guess->new(
                    'DB',
                    height     => $user_info->height,
                    weight     => $user_info->weight,
                    gender     => $user_info->gender,
                    _time_zone => $self->config->{timezone},
                    _schema    => $self->schema,
                );

                $guess_info = $guess->guess;
            }
        }
        else {
            my $knee = $AVG_KNEE_BY_HEIGHT{$height};
            unless ( $guess_info->{knee} = $knee ) {
                my $guess = OpenCloset::Size::Guess->new(
                    'DB',
                    height     => $user_info->height,
                    weight     => $user_info->weight,
                    gender     => $user_info->gender,
                    _time_zone => $self->config->{timezone},
                    _schema    => $self->schema,
                );

                $guess_info = $guess->guess;
            }
        }

        $self->render(
            staff    => \@staff,
            guess    => $guess_info,
            template => 'order/purchase.payment_done'
        );
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
    $v->optional('status_id');

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter Validation Failed: ' . join( ', ', @$failed ) );
    }

    my $parcel_service = $v->param('parcel-service');
    my $waybill        = $v->param('waybill');
    my $comment        = $v->param('comment');
    my $status_id      = $v->param('status_id');

    if ( $parcel_service or $waybill or $comment ) {
        $parcel->parcel_service($parcel_service) if $parcel_service;
        $parcel->waybill($waybill)               if $waybill;
        $parcel->comment($comment)               if $comment;
        $parcel->update();
    }

    if ( $waybill && $parcel->status_id == $WAITING_SHIPPED ) {
        ## 운송장이 입력되면 배송중으로 변경한다
        $self->update_parcel_status( $order, $SHIPPED );
    }
    elsif ($status_id) {
        $self->update_parcel_status( $order, $status_id );
    }

    $self->respond_to(
        html => sub    { shift->redirect_to('order.purchase') },
        json => { json => { $parcel->get_columns } }
    );
}

=head2 create_payment

    POST /order/:order_id/payments

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

    my $amount = $self->category_price($order);
    my $additional = $order->order_details( { desc => 'additional' } );
    while ( my $detail = $additional->next ) {
        my $fee = $detail->price;
        $amount += $fee;
    }

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

=head2 insert_coupon

    POST /orders/:order_id/coupon

=cut

sub insert_coupon {
    my $self  = shift;
    my $order = $self->stash("order");

    my $v = $self->validation;
    $v->required('coupon_id');
    $v->optional('extra');
    return $self->error( 400, "coupon_id is required" ) if $v->has_error;

    my $coupon_id = $self->param('coupon_id');
    my $extra     = $self->param('extra');
    my $coupon    = $self->schema->resultset('Coupon')->find( { id => $coupon_id } );
    return $self->error( 404, "Not found coupon: $coupon_id" ) unless $coupon;

    $coupon->update( { extra => $extra } ) if $extra;

    my $coupon_status = $coupon->status || '';
    return $self->error( 400, "Invalid coupon status: $coupon_status" ) if $coupon_status =~ m/(us|discard|expir)ed/;

    my $type           = $coupon->type;
    my $price_pay_with = '쿠폰';
    if ( $type eq 'suit' ) {
        my $guard = $self->schema->txn_scope_guard;
        my ( $success, $error ) = try {
            $order->update( { price_pay_with => $price_pay_with } );
            $self->transfer_order( $coupon, $order );
            $self->discount_order($order);
            $coupon->update( { status => 'used' } );
            $guard->commit;
            return 1;
        }
        catch {
            chomp;
            return ( undef, $_ );
        };

        return $self->error( 500, $error ) unless $success;
    }
    elsif ( $type =~ /(default|rate)/ ) {
        $price_pay_with .= '+';
        my $guard = $self->schema->txn_scope_guard;
        my ( $success, $error ) = try {
            $order->update( { price_pay_with => $price_pay_with } );
            $self->transfer_order( $coupon, $order );
            $self->discount_order($order);
            $coupon->update( { status => 'used' } );
            $guard->commit;
            return 1;
        }
        catch {
            chomp;
            return ( undef, $_ );
        };

        return $self->error( 500, $error ) unless $success;
    }
    else {
        return $self->error( 500, "Unknown coupon type: $type" );
    }

    my %columns = $order->get_columns;
    $self->render( json => \%columns );
}

=head2 cancel_payment

    POST /orders/:order_id/cancel

=cut

sub cancel_payment {
    my $self  = shift;
    my $order = $self->stash('order');
    my $dates = $self->stash('dates');

    my $cancel_payment = $self->_cancel_payment_cond( $order, $dates->{shipping} );
    return $self->error( 400, 'This order payment can not be canceled.' ) unless $cancel_payment;

    my $v          = $self->validation;
    my $pay_method = $order->price_pay_with;
    if ( $pay_method eq '가상계좌' ) {
        $v->required('refund_holder');
        $v->required('refund_bank')->in(qw/03 04 05 07 11 20 23 31 32 34 37 39 53 71 81 88 D1 D2 D3 D4 D5 D6 D7 D8 D9 DA DB DC DD DE DF/);
        $v->required('refund_account')->like(qr/\d+/);

        if ( $v->has_error ) {
            my $failed = $v->failed;
            return $self->error( 400, '환불계좌정보가 올바르지 않습니다.' );
        }
    }

    if ( $pay_method eq '쿠폰' ) {
        my $coupon = $order->coupon;
        return $self->error( 404, "Not found coupon" ) unless $coupon;

        $coupon->update( { status => 'provided' } ); # TODO: cancelled 가 필요하지 않을까?
        $order->update( { coupon_id => undef, status_id => $PAYBACK } );
    }
    else {
        my $payment_log = $order->payments->search_related( 'payment_logs', { status => 'paid' }, { rows => 1 } )->single;
        my $payment = $payment_log->payment;

        return $self->error( 404, "Not found payment" ) unless $payment;
        return $self->error( 404, "Not found payment from iamport" ) unless $payment->sid;

        my $sid     = $payment->sid;
        my $iamport = $self->app->iamport;
        my $param   = { imp_uid => $sid };

        if ( $pay_method eq '가상계좌' || $pay_method eq 'vbank' ) {
            $param->{refund_holder}  = $v->param('refund_holder');
            $param->{refund_bank}    = $v->param('refund_bank');
            $param->{refund_account} = $v->param('refund_account');
        }

        my $json = $iamport->cancel($param);
        return $self->error( 500, "Failed to cancel from iamport: sid($sid)" ) unless $json;

        my $res = decode_json($json);
        my $log = $payment->create_related(
            "payment_logs",
            {
                status => $res->{response}{status},
                detail => $json,
            },
        );

        $order->update( { status_id => $PAYBACK } );
    }

    my $user      = $order->user;
    my $user_info = $user->user_info;
    my $msg       = $self->render_to_string(
        'sms/payment/cancel',
        format => 'txt',
        order  => $order,
        user   => $user,
    );
    chomp $msg;
    $self->sms( $user_info->phone, $msg );

    $self->flash( message => '결제가 취소되었습니다.' );
    $self->render( json => { pay_method => $pay_method, status => 'cancelled' } );
}

=head2 _cancel_payment_cond

    my $boolean = $self->_cancel_payment_cond($order, $shipping_date);

=cut

sub _cancel_payment_cond {
    my ( $self, $order, $shipping_date ) = @_;
    return unless $order;
    return unless $shipping_date;

    my $today = DateTime->today( time_zone => $self->config->{timezone} );
    my $pay_method = $order->price_pay_with || '';
    my $cancel_payment = $today->epoch < $shipping_date->epoch && $pay_method;

    return $cancel_payment;
}

1;
