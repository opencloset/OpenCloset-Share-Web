package OpenCloset::Share::Web::Controller::Measurement;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;

has schema => sub { shift->app->schema };

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

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter validation failed: ' . join( ', ', @$failed ) );
    }

    my $user      = $self->stash('user');
    my $user_info = $self->stash('user_info');
    return $self->error( 500, 'Not found user_info' ) unless $user_info;

    my $input = $v->input || {};
    map { $input->{$_} ||= 0 } keys %$input;
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
