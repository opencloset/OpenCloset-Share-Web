package OpenCloset::Share::Web;
use Mojo::Base 'Mojolicious';

=head1 METHODS

=head2 startup

This method will run once at server start

=cut

sub startup {
    my $self = shift;

    $self->plugin('Config');
    $self->plugin('OpenCloset::Plugin::Helpers');

    $self->secrets( $self->config->{secrets} );
    $self->sessions->cookie_domain( $self->config->{cookie_domain} );
    $self->sessions->cookie_name('opencloset');
    $self->sessions->default_expiration(86400);

    $self->_public_routes;
    $self->_private_routes;
}

sub _public_routes {
    my $self = shift;
    my $r    = $self->routes;

    $r->get('/')->to('root#index')->name('root.index');
}

sub _private_routes { }

1;
