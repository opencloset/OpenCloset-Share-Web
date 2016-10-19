package OpenCloset::Share::Web::Command::returning2returned;

use Mojo::Base 'Mojolicious::Command';

use Parcel::Track;

use OpenCloset::Schema;
use OpenCloset::Constants::Status qw/$RETURNING $RETURNED/;

binmode STDOUT, ':utf8';
STDOUT->autoflush(1);

has description => 'Update status returning to returned if ready';
has usage       => "Usage: APPLICATION returning2returned\n";
has driver      => 'KR::CJKorea';

=encoding utf-8

=head1 NAME

OpenCloset::Share::Web::Command::returning2returned

=head1 SYNOPSIS

    $ MOJO_CONFIG=/path/to/share.conf ./script/share returning2returned

=head1 METHODS

=head2 run

=cut

sub run {
    my $self   = shift;
    my $schema = $self->app->schema;

    while (1) {
        my $rs = $schema->resultset('Order')->search( { status_id => $RETURNING } );
        while ( my $order = $rs->next ) {
            my $parcel = $order->order_parcel;
            next unless $parcel;

            my $waybill = $parcel->return_waybill;
            next unless $waybill;

            my $tracker = Parcel::Track->new( $self->driver, $waybill );
            my $result = $tracker->track;
            next unless $result;

            my $latest = pop @{ $result->{descs} };
            next unless $latest =~ /배달완료/;

            $self->app->update_parcel_status( $order, $RETURNED );
            printf(
                "[%d]: %s -> %s", $order->id, $OpenCloset::Constants::Status::LABEL_MAP{$RETURNING},
                $OpenCloset::Constants::Status::LABEL_MAP{$RETURNED}
            );

            sleep(1);
        }

        sleep( 60 * 60 ); # 1시간마다
    }
}

1;
