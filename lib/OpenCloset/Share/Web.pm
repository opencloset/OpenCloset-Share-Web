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
    $self->plugin('Number::Commify');
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
    $r->get('/webhooks/import')->to('root#import_hook');
}

sub _private_routes {
    my $self = shift;
    my $root = $self->routes;

    my $r            = $root->under('/')->to('user#auth');
    my $measurements = $root->under('/measurements')->to('user#auth');
    my $clothes      = $root->under('/clothes')->to('user#auth');
    my $order        = $root->under('/order')->to('user#auth');

    $r->get('/')->to('root#index')->name('index');
    $r->get('/logout')->to('user#logout')->name('logout');

    $measurements->get('/')->to('measurement#index');
    $measurements->post('/')->to('measurement#update');

    $clothes->get('/recommend')->to('clothes#recommend');

    $order->get('/new')->to('order#add')->name('order.add');
    $order->post('/')->to('order#create')->name('order.create');

    my $order_id = $order->under('/:order_id')->to('order#order_id');
    $order_id->get('/')->to('order#order')->name('order.order');

    my $clothes_code = $clothes->under('/:code')->to('clothes#code');
    $clothes_code->get('/')->to('clothes#detail');
}

1;
