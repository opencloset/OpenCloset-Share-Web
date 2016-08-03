package OpenCloset::Share::Web::Controller::Root;
use Mojo::Base 'Mojolicious::Controller';

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 index

    # index
    GET /

=cut

sub index {
    my $self = shift;
    my $user = $self->stash('user');

    my $failed = $self->_check_measurement;
    my $orders = $self->schema->resultset('Order')->search( { user_id => $user->id }, { order_by => { -desc => 'id' } } );
    $self->render( failed => $failed, orders => $orders );
}

=head3 _check_measurement

    my $failed = $self->_check_measurement;

=cut

sub _check_measurement {
    my $self      = shift;
    my $user      = $self->stash('user');
    my $user_info = $self->stash('user_info');

    my $user_id = $user->id;
    my $gender = $user_info->gender || 'male'; # TODO: 원래 없으면 안됨

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
        return ["gender($msg)"];
    }

    return $v->failed if $v->has_error;
    return;
}

=head2 import_hook

    GET /webhooks/import

=cut

sub import_hook {
    my $self = shift;

    my $url = $self->req->url->to_abs;
    $self->log->debug($url);

    $self->render( text => $url );
}

1;
