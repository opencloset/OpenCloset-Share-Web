package OpenCloset::Share::Web::Controller::Clothes;
use Mojo::Base 'Mojolicious::Controller';

use HTTP::Tiny;
use Mojo::JSON qw/decode_json/;
use Mojo::URL;

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 recommend

    GET /clothes/recommend

=cut

sub recommend {
    my $self     = shift;
    my $order_id = $self->param('order_id');

    my $order = $self->schema->resultset('Order')->find( { id => $order_id } );
    return $self->error( 404, "Not found order: $order_id" ) unless $order;

    my $user = $order->user;
    return $self->error( 404, 'Not found user' ) unless $user;

    my $user_id = $user->id;

    my $cookie = $self->app->_auth_opencloset;
    return $self->error( 500, "Failed to authentication to API server" ) unless $cookie;

    my $http = HTTP::Tiny->new(
        cookie_jar      => $cookie,
        default_headers => {
            cookie => "opencloset=$cookie",
            accept => 'application/json',
        }
    );

    my $url = Mojo::URL->new( $self->config->{opencloset}{root} );
    $url->path("/api/user/$user_id/search/clothes");

    my $res = $http->get($url);
    return $self->error( 500, "Couldn't get recommended clothes from API server" )
        unless $self->is_success($res);

    my $data = decode_json( $res->{content} );

    my @recommends;
    my $rs = $self->schema->resultset('Clothes');
    for my $recommend ( @{ $data->{result} } ) {
        my ( $top, $bottom, $count ) = @$recommend;
        my $code;
        $code = sprintf( '%05s', $top );
        my $t = $rs->find( { code => $code } );

        $code = sprintf( '%05s', $bottom );
        my $b = $rs->find( { code => $code } );

        push @recommends, [ $t, $b, $count ];
    }

    $self->respond_to(
        html => sub {
            $self->render( recommends => \@recommends, order_id => $order_id );
        },
        json => { json => $data->{result} },
    );
}

=head2 code

    under /clothes/:code

=cut

sub code {
    my $self = shift;
    my $code = $self->param('code');

    my $clothes = $self->schema->resultset('Clothes')->find( { code => sprintf( '%05s', $code ) } );
    unless ($clothes) {
        $self->error( 404, "Not found clothes: $code" );
        return;
    }

    $self->stash( clothes => $clothes );
    return 1;
}

=head2 detail

    GET /clothes/:code

=cut

sub detail {
    my $self     = shift;
    my $clothes  = $self->stash('clothes');
    my $order_id = $self->param('order_id');

    my $code = $clothes->code =~ s/^0//r;
    my $url  = $self->oavatar_url($code) . '/images';

    $self->log->debug("Clothes images URL: $url");

    my $http = HTTP::Tiny->new;
    my $res = $http->get( $url, { headers => { Accept => 'application/json' } } );

    my @images;
    if ( $res->{success} ) {
        my $urls = decode_json( $res->{content} );
        @images = @$urls;
    }
    else {
        $self->log->error("Failed to get $code images: $res->{reason}");
    }

    my @measurements = $self->clothes_measurements($clothes);
    my ( @parts, @sizes );
    while ( my ( $part, $size ) = splice( @measurements, 0, 2 ) ) {
        push @parts, $part;
        push @sizes, $size;
    }

    my $order;
    if ($order_id) {
        $order = $self->schema->resultset('Order')->find( { id => $order_id } );
        return $self->error( 404, "Order not found: $order_id" ) unless $order;

        my $user = $self->stash('user');
        return $self->error( 400, "Permission denied" ) if $user->id != $order->user_id;
    }

    $self->stash( images => \@images, parts => \@parts, sizes => \@sizes, order => $order );
    $self->respond_to(
        html => { template => 'clothes/detail' },
        json => sub {
            my %columns = $clothes->get_columns;
            $self->render( json => \%columns );
        }
    );
}

1;
