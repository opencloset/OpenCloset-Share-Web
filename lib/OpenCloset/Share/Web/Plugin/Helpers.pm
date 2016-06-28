package OpenCloset::Share::Web::Plugin::Helpers;

use Mojo::Base 'Mojolicious::Plugin';

use HTTP::Tiny;
use Mojo::JSON qw/decode_json/;

use OpenCloset::Schema;

=encoding utf8

=head1 NAME

OpenCloset::Share::Web::Plugin::Helpers - opencloset share web mojo helper

=head1 SYNOPSIS

    # Mojolicious::Lite
    plugin 'OpenCloset::Share::Web::Plugin::Helpers';

    # Mojolicious
    $self->plugin('OpenCloset::Share::Web::Plugin::Helpers');

=cut

sub register {
    my ( $self, $app, $conf ) = @_;

    $app->helper( agent        => \&agent );
    $app->helper( current_user => \&current_user );
    $app->helper( is_success   => \&is_success );
}

=head1 HELPERS

=head2 agent

    my $agent = $self->agent;    # HTTP::Tiny object
    my $res   = $agent->get('https://staff.theopencloset.net/api/user/30000');

=cut

sub agent {
    my $self = shift;

    my $agent  = __PACKAGE__;
    my $cookie = $self->cookie('opencloset');

    unless ($cookie) {
        $self->log->error('Not found cookie: opencloset');
        return;
    }

    my $http = HTTP::Tiny->new(
        default_headers => {
            agent  => $agent,
            cookie => "opencloset=$cookie",
            accept => 'application/json',
        }
    );

    return $http;
}

=head2 current_user

    my $user = $self->current_user;

=cut

sub current_user {
    my $self = shift;

    my $id = $self->session('access_token');
    unless ($id) {
        $self->log->error('Not found session: access_token');
        return;
    }

    my $user = $self->schema->resultset('User')->find( { id => $id } );
    unless ($user) {
        $self->log->error("Not found user: $id");
        return;
    }

    return $user;
}

=head2 is_success

print error log unless C<$res->{success}>

    my $res = $agent->get('somewhere');
    return $self->error(xxx, 'blahblah') unless $self->is_success($res);

    # do something

=cut

sub is_success {
    my ( $self, $res ) = @_;
    return unless $res;
    return $res if $res->{success};

    my $url     = $res->{url};
    my $content = decode_json( $res->{content} );
    my $error   = $content->{error};
    $self->log->error("Failed to request $url: $error");
    return;
}

1;
