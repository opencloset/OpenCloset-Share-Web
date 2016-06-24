package OpenCloset::Share::Web;
use Mojo::Base 'Mojolicious';

use OpenCloset::Schema;

has schema => sub {
    my $self   = shift;
    my $conf   = $self->config->{database};
    my $schema = OpenCloset::Schema->connect(
        {
            dsn => $conf->{dsn}, user => $conf->{user}, password => $conf->{pass},
            %{ $conf->{opts} },
        }
    );

    return $schema;
};

=head1 METHODS

=head2 startup

This method will run once at server start

=cut

sub startup {
    my $self = shift;

    $self->plugin('Config');
    $self->plugin('OpenCloset::Plugin::Helpers');
    $self->plugin('OpenCloset::Share::Web::Plugin::Helpers');

    $self->secrets( $self->config->{secrets} );
    $self->sessions->cookie_domain( $self->config->{cookie_domain} );
    $self->sessions->cookie_name('opencloset');
    $self->sessions->default_expiration(86400);

    $self->_assets;
    $self->_public_routes;
    $self->_private_routes;
}

sub _assets {
    my $self = shift;

    $self->defaults( jses => [], csses => [] );
}

sub _public_routes {
    my $self = shift;
    my $r    = $self->routes;

    $r->get('/welcome')->to('welcome#index')->name('welcome');
}

sub _private_routes {
    my $self = shift;
    my $r    = $self->routes->under('/')->to('user#auth');

    $r->get('/')->to('root#index')->name('root.index');
}

1;
