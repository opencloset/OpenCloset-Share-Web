package OpenCloset::Share::Web::Plugin::Helpers;

use Mojo::Base 'Mojolicious::Plugin';

use HTTP::Tiny;
use Mojo::ByteStream;
use Mojo::JSON qw/decode_json/;

use OpenCloset::Schema;
use OpenCloset::Constants::Status;

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

    $app->helper( agent            => \&agent );
    $app->helper( current_user     => \&current_user );
    $app->helper( is_success       => \&is_success );
    $app->helper( trim_code        => \&trim_code );
    $app->helper( clothes2desc     => \&clothes2desc );
    $app->helper( order2link       => \&order2link );
    $app->helper( order_categories => \&order_categories );
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

=head2 trim_code

trim clothes code

    % trim_code('0J001')
    # J001

=cut

sub trim_code {
    my ( $self, $clothes_or_code ) = @_;
    return '' unless $clothes_or_code;

    my $code;
    if ( ref $clothes_or_code ) {
        $code = $clothes_or_code->code;
    }
    else {
        $code = $clothes_or_code;
    }

    $code =~ s/^0//;
    return $code;
}

=head2 clothes2desc

    % clothes2desc($clothes)
    # 가슴 99 / 허리 88 black

Support only a suit of top bottom set.

=cut

sub clothes2desc {
    my ( $self, $clothes ) = @_;
    return '' unless $clothes;

    my $top    = $clothes->top;
    my $bottom = $clothes->bottom;

    return '' unless $top;
    return '' unless $bottom;

    my $bust  = $top->bust      || 'Unknown';
    my $waist = $bottom->waist  || 'Unknown';
    my $color = $clothes->color || 'Unknown';

    return sprintf "가슴 %s / 허리 %s %s", $bust, $waist, $color;
}

=head2 order2link

    % order2link($order, @class)
    # <a href="/order/35155" class="btn btn-link">
    #   2016-08-01
    #   <small>결제대기</small>
    # </a>

=cut

sub order2link {
    my ( $self, $order, @class ) = @_;
    return '' unless $order;

    push @class, 'btn btn-link' unless @class;

    my $order_id  = $order->id;
    my $status_id = $order->status_id;
    my $ymd       = $order->create_date->ymd;
    my $dom       = Mojo::DOM::HTML->new;

    my $status = $OpenCloset::Constants::Status::LABEL_MAP{$status_id} || 'Unknown';
    my $html = qq{<a href="/order/$order_id" class="@class">
  $ymd
  <small>$status</small>
</a>};
    $dom->parse($html);
    my $tree = $dom->tree;
    return Mojo::ByteStream->new( Mojo::DOM::HTML::_render($tree) );
}

=head2 order_categories

    my @categories = $self->order_categories($order);

=cut

sub order_categories {
    my ( $self, $order ) = @_;
    return unless $order;

    my @categories;
    my @details = $order->order_details;
    map { push @categories, $_->name } @details;

    return @categories;
}

1;
