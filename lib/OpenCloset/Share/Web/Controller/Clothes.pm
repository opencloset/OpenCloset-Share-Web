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

    my $user = $self->current_user;
    return $self->error( 500, 'Not found current user' ) unless $user;

    my $data = $self->session('recommend');
    unless ($data) {
        my $agent = $self->agent;
        return $self->error( 500, "Couldn't get agent" ) unless $agent;

        my $user_id = $user->id;
        my $url     = Mojo::URL->new( $self->config->{opencloset}{root} );
        $url->path("/api/user/$user_id/search/clothes");

        my $res = $agent->get($url);
        return $self->error( 500, "Couldn't get recommended clothes from API server" )
            unless $self->is_success($res);

        $data = decode_json( $res->{content} );
        $self->session( 'recommend' => $data );
    }

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

    $self->render( recommends => \@recommends, order_id => $order_id );
}

=head2 code

    under /clothes/:code

=cut

sub code {
    my $self = shift;
    my $code = $self->param('code');

    my $clothes = $self->schema->resultset('Clothes')->find( { code => sprintf( '%05s', $code ) } );
    $self->stash( clothes => $clothes );
}

=head2 detail

    GET /clothes/:code

=cut

sub detail {
    my $self    = shift;
    my $clothes = $self->stash('clothes');

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

    $self->render( images => \@images, parts => \@parts, sizes => \@sizes );
}

1;
