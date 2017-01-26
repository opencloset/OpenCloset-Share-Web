package OpenCloset::Share::Web::Command::iamport;
use Mojo::Base 'Mojolicious::Commands';

has description => 'api.iamport.kr REST API commands';
has namespaces => sub { ['OpenCloset::Share::Web::Command::iamport'] };

sub help { shift->run(@_) }

1;

=encoding utf-8

=head1 NAME

OpenCloset::Share::Web::Command::iamport - iamport command

=head1 SYNOPSIS

    $ ./script/share iamport cancel <order_id>

=cut
