package OpenCloset::Share::Web::Controller::User;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 auth

    under /

=cut

sub auth {
    my $self = shift;

    my $user_id = $self->session('access_token');
    unless ($user_id) {
        my $login = Mojo::URL->new( $self->config->{opencloset}{login} );
        $login->query( return => $self->req->url->to_abs );
        $self->redirect_to($login);
        return;
    }

    my $user = $self->schema->resultset('User')->find( { id => $user_id } );
    my $user_info = $user->user_info;

    $self->stash( user => $user, user_info => $user_info );
    return 1;
}

=head2 logout

    # logout
    GET /logout

=cut

sub logout {
    my $self = shift;

    delete $self->session->{access_token};
    $self->redirect_to('welcome');
}

1;
