package OpenCloset::Share::Web::Controller::Body;
use Mojo::Base 'Mojolicious::Controller';

use OpenCloset::Size::Guess;

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 dimensions

    GET /body/dimensions

=cut

sub dimensions {
    my $self = shift;
    my $v    = $self->validation;

    $v->required('gender')->like(qr/^(fe)?male$/);
    $v->required('height')->like(qr/^\d+$/);
    $v->required('weight')->like(qr/^\d+$/);
    $v->optional('bust')->like(qr/^\d+$/);
    $v->optional('topbelly')->like(qr/^\d+$/);
    $v->optional('waist')->like(qr/^\d+$/);
    $v->optional('hip')->like(qr/^\d+$/);
    $v->optional('thigh')->like(qr/^\d+$/);
    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter validation failed: ' . join( ', ', @$failed ) );
    }

    my $gender   = $v->param('gender');
    my $height   = $v->param('height');
    my $weight   = $v->param('weight');
    my $bust     = $v->param('bust');
    my $topbelly = $v->param('topbelly');
    my $waist    = $v->param('waist');
    my $hip      = $v->param('hip');
    my $thigh    = $v->param('thigh');

    my $guess = OpenCloset::Size::Guess->new(
        'DB',
        height     => $height,
        weight     => $weight,
        gender     => $gender,
        _time_zone => $self->config->{timezone},
        _schema    => $self->schema,
        _waist     => $waist,
        _bust      => $bust,
        _topbelly  => $topbelly,
        _hip       => $hip,
    );

    my $info = $guess->guess;
    return $self->error( 404, "조건에 맞는 결과가 없습니다." ) unless $info->{count}{total};
    map { $info->{$_} = int( $info->{$_} || 0 ) } qw/arm belly bust foot height hip knee leg thigh topbelly waist weight/;

    my $ready_to_wear_size = $self->ready_to_wear_size({
        gender   => $gender,
        height   => $height,
        weight   => $weight,
        bust     => $bust     || $info->{bust},
        topbelly => $topbelly || $info->{topbelly},
        waist    => $waist    || $info->{waist},
        hip      => $hip      || $info->{hip},
        thigh    => $thigh    || $info->{thigh},
    });

    $info->{ready_to_wear_size} = $ready_to_wear_size;
    $self->render( json => $info );
}

1;
