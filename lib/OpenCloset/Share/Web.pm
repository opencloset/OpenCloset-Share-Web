package OpenCloset::Share::Web;
use Mojo::Base 'Mojolicious';

use Email::Valid ();
use HTTP::CookieJar;
use HTTP::Tiny;
use Path::Tiny;

use Iamport::REST::Client;
use OpenCloset::Schema;

use version; our $VERSION = qv("v0.0.1");

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

has iamport => sub {
    my $self = shift;
    my $conf = $self->config->{iamport};
    return Iamport::REST::Client->new( key => $conf->{key}, secret => $conf->{secret} );
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
    $r->get('/features')->to('welcome#features');
    $r->get('/signup')->to('user#add');
    $r->post('/verify')->to('user#verify');
    $r->get('/reset')->to('user#reset');
    $r->post('/reset')->to('user#reset_password');
    $r->get('/login')->to('user#login');
    $r->post('/users')->to('user#create');
    $r->get('/terms')->to('root#terms');
    $r->get('/privacy')->to('root#privacy');

    my $hook_route = "/webhooks/iamport";
    if ( $self->config->{iamport} && $self->config->{iamport}{notice_url} ) {
        my $notice_url = $self->config->{iamport}{notice_url};
        $hook_route = $notice_url if $notice_url =~ m{^/};
    }
    $r->post($hook_route)->to('hook#iamport');
}

sub _private_routes {
    my $self = shift;
    my $root = $self->routes;

    my $r            = $root->under('/')->to('user#auth');
    my $measurements = $root->under('/measurements')->to('user#auth');
    my $clothes      = $root->under('/clothes')->to('user#auth');
    my $orders       = $root->under('/orders')->to('user#auth');
    my $payments     = $root->under('/payments')->to('user#auth');
    my $address      = $root->under('/address')->to('user#auth');
    my $sms          = $root->under('/sms')->to('user#auth');

    $r->get('/')->to('root#index')->name('index');
    $r->get('/logout')->to('user#logout')->name('logout');
    $r->get('/search')->to('root#search')->name('search');
    $r->get('/settings')->to('user#settings');
    $r->post('/settings')->to('user#update_settings');
    $r->post('/coupon/validate')->to('coupon#validate');

    $measurements->get('/')->to('measurement#index');
    $measurements->post('/')->to('measurement#update');

    $clothes->get('/recommend')->to('clothes#recommend');

    $orders->get('/new')->to('order#add')->name('order.add');
    $orders->post('/')->to('order#create')->name('order.create');
    $orders->get('/shipping')->to('order#shipping_list');
    $orders->get('/')->to('order#list');
    $orders->get('/dates')->to('order#dates');

    my $order = $orders->under('/:order_id')->to('order#order_id');
    $order->get('/')->to('order#order')->name('order.order');
    $order->put('/')->to('order#update_order')->name('order.update');
    $order->delete('/')->to('order#delete_order')->name('order.delete');
    $order->get('/purchase')->to('order#purchase')->name('order.purchase');
    $order->any( [ 'POST', 'PUT' ] => '/parcel' )->to('order#update_parcel')->name('order.update_parcel');
    $order->post('/payments')->to('order#create_payment');

    my $payment = $payments->under('/:payment_id')->to('payment#payment_id');
    $payment->put('/')->to('payment#update_payment');
    $payment->get('/callback')->to('payment#callback'); # IMP.request_pay m_redirect_url

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

sub _auth_opencloset {
    my $self = shift;

    my $opencloset = $self->config->{opencloset};
    my $cookie     = path( $opencloset->{api}{cookie} )->touch;
    my $cookiejar  = HTTP::CookieJar->new->load_cookies( $cookie->lines );
    my $http       = HTTP::Tiny->new( timeout => 3, cookie_jar => $cookiejar );

    my ($cookies) = $cookiejar->cookies_for( $opencloset->{root} );
    my $expires   = $cookies->{expires};
    my $now       = time;
    if ( !$expires || $expires < $now ) {
        my $email    = $opencloset->{api}{email};
        my $password = $opencloset->{api}{password};
        my $url      = $opencloset->{login};
        my $res      = $http->post_form(
            $url,
            { email => $email, password => $password, remember => 1 }
        );

        ## 성공일때 응답코드가 302 인데, 이는 실패했을때와 마찬가지이다.
        if ( $res->{status} == 302 && $res->{headers}{location} eq '/' ) {
            $cookie->spew( join "\n", $cookiejar->dump_cookies );
        }
        else {
            $self->log->error("Failed Authentication to Opencloset");
            $self->log->error("$res->{status} $res->{reason}");
        }
    }

    return $cookiejar;
}

1;
