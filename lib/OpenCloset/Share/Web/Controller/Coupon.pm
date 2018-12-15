package OpenCloset::Share::Web::Controller::Coupon;
use Mojo::Base 'Mojolicious::Controller';

use OpenCloset::Constants qw/%MAX_SUIT_TYPE_COUPON_PRICE/;

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 validate

    POST /coupon/validate

=cut

sub validate {
    my $self = shift;
    my $v    = $self->validation;

    $v->required('code');
    return $self->error( 400, "쿠폰코드를 입력해주세요" ) if $v->has_error;

    my $order_id = $self->param('order_id');
    my $order = $self->schema->resultset('Order')->find( { id => $order_id } );
    return $self->error( 404, "Not found order: $order_id" ) unless $order;

    my $codes = $v->every_param('code');
    my $code = join( '-', @$codes );
    my ( $coupon, $err ) = $self->coupon_validate($code);
    return $self->error( 400, $err ) if $err;

    ## 쿠폰 타입에 따라 사용가능여부 체크 (#218)
    my $event = $coupon->event;
    if ($event && $event->end_date) {
        if (my $event_type = $event->event_type) {
            my ($start_type, $end_type) = split /\|/, $event_type->type;
            if ($end_type eq 'rental' && $order->wearon_date) {
                my $wearon_date = $order->wearon_date;
                my $rental_date = $wearon_date->clone->subtract( days => 1 );
                if ($event->end_date->epoch < $rental_date->epoch) {
                    return $self->error(400, sprintf(
                        "%s 이벤트기간에만(%s ~ %s) 사용할 수 있습니다. 의류착용일이 %s 이전이어야 합니다.",
                        $event->title,
                        $event->start_date->ymd,
                        $event->end_date->ymd,
                        $event->end_date->ymd,
                    ));
                }
            }
        }
    }

    my $desc = $coupon->desc || '';
    if ( $desc =~ m/^seoul-2018/ ) {
        ## 취업날개는 쿠폰은 입사면접 용도만을 허용 (#178)
        if ( $order->purpose ne '입사면접' ) {
            return $self->error(
                400,
                "대여목적이 입사면접이 아니므로 취업날개 쿠폰을 이용할 수 없습니다. 다른목적으로 이용하길 원하는 경우 대여주문서를 다시 작성해주세요."
            );
        }

        ## 주소지가 서울시인 사람만 취업날개 이용 가능하도록 제한 (#187)
        my $address2;
        if ( my $addr = $order->user_address ) {
            $address2 = $addr->address2 || '';
        }
        else {
            my $user      = $order->user;
            my $user_info = $user->user_info;
            $address2 = $user_info->address2 || '';
        }

        if ( $address2 !~ m/^서울특별시/ ) {
            return $self->error(
                400,
                "취업날개 온라인(택배)대여는 서울 지역으로만 배송이 가능합니다. 배송 받을 주소를 서울시 주소로 입력해주세요."
            );
        }

        my $wearon_date = $order->wearon_date;
        return $self->error( 400, "의류착용일을 알 수 없는 주문서 입니다." ) unless $wearon_date;
    }

    my %columns = $coupon->get_columns;
    $columns{max_suit_type_coupon_price} = \%MAX_SUIT_TYPE_COUPON_PRICE;
    if ( $columns{desc} and $columns{desc} eq 'linkstart' ) {
        $columns{help}        = 'LINKStart x 열린옷장';
        $columns{placeholder} = '대학교명을 입력해주세요.';
    }

    $self->render( json => \%columns );
}

1;
