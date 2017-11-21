package OpenCloset::Share::Web::Controller::Coupon;
use Mojo::Base 'Mojolicious::Controller';

use OpenCloset::Constants qw/$MAX_SUIT_COUPON_PRICE/;

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

    ## 취업날개는 쿠폰은 입사면접 용도만을 허용 (#178)
    my $desc = $coupon->desc || '';
    if ( $desc =~ m/^seoul-2017-2/ and $order->purpose ne '입사면접' ) {
        return $self->error(
            400,
            "대여목적이 입사면접이 아니므로 취업날개 쿠폰을 이용할 수 없습니다. 다른목적으로 이용하길 원하는 경우 대여주문서를 다시 작성해주세요."
        );
    }

    my %columns = $coupon->get_columns;
    $columns{max_suit_coupon_price} = $MAX_SUIT_COUPON_PRICE;
    if ( $columns{desc} and $columns{desc} eq 'linkstart' ) {
        $columns{help}        = 'LINKStart x 열린옷장';
        $columns{placeholder} = '대학교명을 입력해주세요.';
    }

    $self->render( json => \%columns );
}

1;
