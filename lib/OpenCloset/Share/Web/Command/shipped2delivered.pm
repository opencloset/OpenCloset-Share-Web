package OpenCloset::Share::Web::Command::shipped2delivered;

use Mojo::Base 'Mojolicious::Command';

use Parcel::Track;

use OpenCloset::Schema;
use OpenCloset::Constants::Status qw/$RENTAL $SHIPPED $DELIVERED/;

binmode STDOUT, ':utf8';
STDOUT->autoflush(1);

has description => 'Update status shipped to deliverd if ready';
has usage       => "Usage: APPLICATION shipped2delivered\n";
has driver      => 'KR::CJKorea';

=encoding utf-8

=head1 NAME

OpenCloset::Share::Web::Command::shipped2delivered

=head1 SYNOPSIS

    $ MOJO_CONFIG=/path/to/share.conf ./script/share shipped2delivered

=head1 METHODS

=head2 run

=cut

sub run {
    my $self   = shift;
    my $schema = $self->app->schema;

    while (1) {
        my $rs = $schema->resultset('OrderParcel')->search( { 'me.status_id' => $SHIPPED, 'order.status_id' => $RENTAL }, { join => 'order' } );
        while ( my $parcel = $rs->next ) {
            my $waybill = $parcel->waybill;
            next unless $waybill;

            my $order = $parcel->order;

            $self->app->log->debug( sprintf( "Tracking order(%d): %s", $order->id, $waybill ) );

            my $tracker = Parcel::Track->new( $self->driver, $waybill );
            my $result = $tracker->track;
            next unless $result;

            my $latest = pop @{ $result->{descs} };
            next unless $latest =~ /배달완료/;

            $self->app->update_parcel_status( $order, $DELIVERED );
            printf(
                "[%d]: %s -> %s", $order->id, $OpenCloset::Constants::Status::LABEL_MAP{$SHIPPED},
                $OpenCloset::Constants::Status::LABEL_MAP{$DELIVERED}
            );

            sleep(1);
        }

        sleep( 60 * 30 ); # 30분 마다
    }
}

1;
