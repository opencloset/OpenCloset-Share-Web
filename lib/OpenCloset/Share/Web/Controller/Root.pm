package OpenCloset::Share::Web::Controller::Root;
use Mojo::Base 'Mojolicious::Controller';

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 index

    # index
    GET /

=cut

sub index {
    my $self      = shift;
    my $user      = $self->stash('user');
    my $user_info = $self->stash('user_info');

    my $user_id = $user->id;
    my $gender = $user_info->gender || 'male'; # 원래 없으면 안됨

    my $input = {};
    map { $input->{$_} = $user_info->$_ } qw/height weight bust topbelly arm waist thigh leg hip knee/;

    my $v = $self->validation;
    $v->input($input);
    $v->required('height')->size( 3, 3 );
    $v->required('weight')->size( 2, 3 );
    $v->required('bust')->size( 2, 3 );
    $v->required('topbelly')->size( 2, 3 );
    $v->required('arm')->size( 2, 3 );

    if ( $gender eq 'male' ) {
        $v->required('waist')->size( 2, 3 );
        $v->required('thigh')->size( 2, 3 );
        $v->required('leg')->size( 2, 3 );
    }
    elsif ( $gender eq 'female' ) {
        $v->required('hip')->size( 2, 3 );
        $v->required('knee')->size( 2, 3 );
    }
    else {
        my $msg = "Wrong user gender: $gender($user_id)";
        $self->log->error($msg);
        return $self->error( 500, $msg );
    }

    if ( $v->has_error ) {
        my $failed = $v->failed;
        $self->stash( failed => $failed );
    }
    else {
        $self->stash( failed => undef );
    }

    $self->render;
}

1;
