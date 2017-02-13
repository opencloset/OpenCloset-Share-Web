package OpenCloset::Share::Web::Controller::Coupon;
use Mojo::Base 'Mojolicious::Controller';

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
    my $codes    = $v->every_param('code');
    my $code     = join( '-', @$codes );
    my ( $coupon, $err ) = $self->validate_code($code);
    $self->error( 400, $err ) if $err;

    my %columns = $coupon->get_columns;
    $self->render( json => \%columns );
}

1;
