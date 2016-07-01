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
    $v->optional('belly')->size( 2, 3 );
    $v->optional('arm')->size( 2, 3 );
    $v->optional('pants')->size( 2, 3 );
    $v->optional('hip')->size( 2, 3 );

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter validation failed: ' . join( ', ', @$failed ) );
    }

    my $user = $self->current_user;
    return $self->error( 500, 'Not found current user' ) unless $user;

    my $agent = $self->agent;
    return $self->error( 500, "Couldn't get agent" ) unless $agent;

    my $input  = $v->input;
    my $params = $agent->www_form_urlencode($input);
    my $url    = Mojo::URL->new( $self->config->{opencloset}{root} . "?$params" );
    $url->path( '/api/user/' . $user->id );
    my $res = $agent->request( 'PUT', $url );

    if ( $self->is_success($res) ) {
        delete $self->session->{recommend};
        $self->flash( message => 'Successfully update measurements' );
    }
    else {
        $self->flash( message => 'Failed to update measurements', has_error => 1 );
    }

    $self->redirect_to('/measurements');
}

1;
