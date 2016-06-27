package OpenCloset::Share::Web::Plugin::Helpers;

use Mojo::Base 'Mojolicious::Plugin';

use HTTP::Tiny;

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

    $app->helper( agent => \&agent );
}

=head1 HELPERS

=head2 agent

    my $agent = $self->agent;    # HTTP::Tiny object
    my $res   = $agent->get('/api/user/30000.json');

=cut

sub agent {
    my $self = shift;

    my $agent  = __PACKAGE__;
    my $cookie = $self->cookie('opencloset');
    my $http   = HTTP::Tiny->new( default_headers => { agent => $agent, cookie => "opencloset=$cookie" } );

    return $http;
}

1;
