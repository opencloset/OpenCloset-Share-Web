package OpenCloset::Share::Web;
use Mojo::Base 'Mojolicious';

use Email::Valid ();

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

    push @{ $self->commands->namespaces }, 'OpenCloset::Share::Web::Command';

    $self->_assets;
    $self->_public_routes;
    $self->_private_routes;
    $self->_extend_validator;
}

sub _assets {
    my $self = shift;

    $self->defaults( jses => [], csses => [] );
}

sub _public_routes {
    my $self = shift;
    my $r    = $self->routes;

    $r->get('/welcome')->to('welcome#index')->name('welcome');
    $r->get('/users/new')->to('user#add');
    $r->post('/users')->to('user#create');
    $r->get('/terms')->to('root#terms');
    $r->get('/privacy')->to('root#privacy');
    $r->post('/webhooks/import')->to('root#import_hook');
}

sub _private_routes {
    my $self = shift;
    my $root = $self->routes;

    my $r            = $root->under('/')->to('user#auth');
    my $measurements = $root->under('/measurements')->to('user#auth');
    my $clothes      = $root->under('/clothes')->to('user#auth');
    my $orders       = $root->under('/orders')->to('user#auth');
    my $address      = $root->under('/address')->to('user#auth');
    my $sms          = $root->under('/sms')->to('user#auth');

    $r->get('/')->to('root#index')->name('index');
    $r->get('/logout')->to('user#logout')->name('logout');
    $r->get('/search')->to('root#search')->name('search');
    $r->get('/verify')->to('user#verify_form');
    $r->post('/verify')->to('user#verify');

    $measurements->get('/')->to('measurement#index');
    $measurements->post('/')->to('measurement#update');

    $clothes->get('/recommend')->to('clothes#recommend');

    $orders->get('/new')->to('order#add')->name('order.add');
    $orders->post('/')->to('order#create')->name('order.create');
    $orders->get('/')->to('order#list')->name('order.list');

    my $order = $orders->under('/:order_id')->to('order#order_id');
    $order->get('/')->to('order#order')->name('order.order');
    $order->put('/')->to('order#update_order')->name('order.update');
    $order->delete('/')->to('order#delete_order')->name('order.delete');
    $order->get('/purchase')->to('order#purchase')->name('order.purchase');
    $order->any( [ 'POST', 'PUT' ] => '/parcel' )->to('order#update_parcel')->name('order.update_parcel');

    my $clothes_code = $clothes->under('/:code')->to('clothes#code');
    $clothes_code->get('/')->to('clothes#detail');

    $address->post('/')->to('address#create');
    $address->put('/:address_id')->to('address#update_address');
    $address->delete('/:address_id')->to('address#delete_address');

    $sms->post('/')->to('sms#create')->name('sms.create');
}

sub _extend_validator {
    my $self = shift;

    $self->validator->add_check(
        email => sub {
            my ( $v, $name, $value ) = @_;
            return not Email::Valid->address($value);
        }
    );
}

1;
