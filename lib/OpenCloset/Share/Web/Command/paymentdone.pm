package OpenCloset::Share::Web::Command::paymentdone;

use Mojo::Base 'Mojolicious::Command';

has description => 'Update order status to $PAYMENT_DONE';
has usage       => "Usage: APPLICATION paymentdone :order_id\n";

binmode STDOUT, ':utf8';

=encoding utf-8

=head1 NAME

OpenCloset::Share::Web::Command::paymentdone

=head1 SYNOPSIS

    $ MOJO_CONFIG=/path/to/share.conf ./script/share paymentdone 58037

=head1 METHODS

=head2 run

=cut

sub run {
    my ( $self, $order_id ) = @_;

    my $dt;
    my $app    = $self->app;
    my $schema = $app->schema;

    my $order = $schema->resultset('Order')->find( { id => $order_id } );
    die "Order not found: $order_id" unless $order;

    $app->payment_done($order);
}

1;
