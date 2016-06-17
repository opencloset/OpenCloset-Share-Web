package OpenCloset::Share::Web::Controller::Root;
use Mojo::Base 'Mojolicious::Controller';

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 index

    # root.index
    GET /

=cut

sub index {
    my $self = shift;

    my $user_id   = $self->session('access_token');
    my $user      = $self->schema->resultset('User')->find( { id => $user_id } );
    my $user_info = $user->user_info;

    $self->render( user => $user, user_info => $user_info );
}

1
