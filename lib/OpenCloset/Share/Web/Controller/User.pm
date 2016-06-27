package OpenCloset::Share::Web::Controller::User;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;

=head1 METHODS

=head2 auth

    under /

=cut

sub auth {
    my $self = shift;

    unless ( $self->session('access_token') ) {
        my $login = Mojo::URL->new( $self->config->{opencloset}{login} );
        $login->query( return => $self->req->url->to_abs );
        $self->redirect_to($login);
        return;
    }

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
