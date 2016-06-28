package OpenCloset::Share::Web::Controller::Clothes;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;
use Mojo::JSON qw/decode_json/;

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 recommend

    GET /clothes/recommend

=cut

sub recommend {
    my $self = shift;

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

    $self->render( recommends => \@recommends );
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
}

1;
