package OpenCloset::Share::Web::Controller::Measurement;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;

has schema => sub { shift->app->schema };

our %TOPBELLY_TOP_SIZE_MAP = (
    67 => 44, 68 => 44, 69 => 44, 70 => 44,
    71 => 55, 72 => 55, 73 => 55, 74 => 55,
    75 => 66, 76 => 66, 77 => 66, 78 => 66, 79 => 66, 80 => 66,
    81  => 77,  82  => 77,  83  => 77,  84  => 77,  85  => 77,
    86  => 88,  87  => 88,  88  => 88,  89  => 88,  90  => 88,
    91  => 99,  92  => 99,  93  => 99,  94  => 99,  95  => 99,
    96  => 100, 97  => 100, 98  => 100, 99  => 100, 100 => 100, 101 => 100,
    102 => 110, 103 => 110, 104 => 110, 105 => 110, 106 => 110,
    107 => 120, 108 => 120, 109 => 120, 110 => 120
);

our %HIP_BOTTOM_SIZE_MAP = (
    81 => 44, 82 => 44, 83 => 44, 84 => 44, 85 => 44,
    86 => 55, 87 => 55, 88 => 55, 89 => 55,
    90 => 66, 91 => 66, 92 => 66, 93 => 66, 94 => 66,
    95  => 77, 96  => 77, 97  => 77, 98  => 77, 99  => 77, 100 => 77,
    101 => 88, 102 => 88, 103 => 88, 104 => 88, 105 => 88, 106 => 88, 107 => 88, 108 => 88,
    109 => 99,  110 => 99,
    111 => 100, 112 => 100, 113 => 100, 114 => 100, 115 => 100, 116 => 100,
    117 => 110, 118 => 110, 119 => 110,
    120 => 120,
);

=head1 METHODS

=head2 index

    GET /measurements

=cut

sub index {
    my $self = shift;

    my $user      = $self->current_user;
    my $user_info = $user->user_info;
    $self->render( user => $user, user_info => $user_info );
}

=head2 update

    POST /measurements

=cut

sub update {
    my $self = shift;

    ## API 와 중복된 validation 이지만 1차 filter 로써 넣어주자
    my $v = $self->validation;
    $v->optional('height')->size( 2, 3 );
    $v->optional('weight')->size( 2, 3 );
    $v->optional('bust')->size( 2, 3 );
    $v->optional('waist')->size( 2, 3 );
    $v->optional('topbelly')->size( 2, 3 );
    $v->optional('arm')->size( 2, 3 );
    $v->optional('thigh')->size( 2, 2 );
    $v->optional('leg')->size( 2, 3 );
    $v->optional('hip')->size( 2, 3 );
    $v->optional('knee')->size( 2, 3 );
    $v->optional('foot')->size( 3, 3 );
    $v->optional('top_size');
    $v->optional('bottom_size');

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter validation failed: ' . join( ', ', @$failed ) );
    }

    my $user      = $self->stash('user');
    my $user_info = $self->stash('user_info');
    return $self->error( 500, 'Not found user_info' ) unless $user_info;

    my $input = $v->input || {};
    map { $input->{$_} ||= 0 } keys %$input;

    ## top_size 와 bottom_size 는 여성이면서 사이즈가 선택되지 않았다면 기본 사이즈로 추천
    if ( $user_info->gender eq 'female' ) {
        my $topbelly    = $input->{topbelly}    || $user_info->topbelly;
        my $hip         = $input->{hip}         || $user_info->hip;
        my $top_size    = $input->{top_size}    || $user_info->top_size;
        my $bottom_size = $input->{bottom_size} || $user_info->bottom_size;

        if ( $topbelly and !$top_size ) {
            $top_size = $TOPBELLY_TOP_SIZE_MAP{ $topbelly + 5 };
            if ( !$top_size and $topbelly + 5 < 67 ) {
                $self->log->warn("최소 범위안에 없습니다: 윗배둘레($topbelly)");
                $top_size = 44;
            }
            elsif ( !$top_size and $topbelly + 5 > 110 ) {
                $self->log->warn("최대 범위안에 없습니다: 윗배둘레($topbelly)");
                $top_size = 120;
            }

            $input->{top_size} = $top_size;
        }

        if ( $hip and !$bottom_size ) {
            $bottom_size = $HIP_BOTTOM_SIZE_MAP{$hip};
            if ( !$bottom_size and $hip < 81 ) {
                $self->log->warn("최소 범위안에 없습니다: 엉덩이둘레($hip)");
                $bottom_size = 44;
            }
            elsif ( !$bottom_size and $hip > 120 ) {
                $self->log->warn("최대 범위안에 없습니다: 엉덩이둘레($hip)");
                $bottom_size = 120;
            }

            $input->{bottom_size} = $bottom_size;
        }
    }

    $user_info->update($input);

    my $failed = $self->check_measurement( $user, $user_info );
    if ($failed) {
        $self->flash( message => 'Successfully update measurements' );
        $self->redirect_to('/measurements');
    }
    else {
        $self->redirect_to('order.add');
    }
}

1;
