package OpenCloset::Share::Web::Command::returnrequested2returning;

use Mojo::Base 'Mojolicious::Command';

use Parcel::Track;

use OpenCloset::Schema;
use OpenCloset::Constants::Status qw/$RETURN_REQUESTED $RETURNING/;

binmode STDOUT, ':utf8';
STDOUT->autoflush(1);

has description => 'Update status return-requested to returning if ready';
has usage       => "Usage: APPLICATION returnrequested2returning\n";
has driver      => 'KR::CJKorea';

=encoding utf-8

=head1 NAME

OpenCloset::Share::Web::Command::returnrequested2returning

=head1 SYNOPSIS

    $ MOJO_CONFIG=/path/to/share.conf ./script/share returnrequested2returning

=head1 METHODS

=head2 run

=cut

sub run {
    my $self   = shift;
    my $schema = $self->app->schema;

    while (1) {
        my $rs = $schema->resultset('Order')->search( { status_id => { -in => qw[$RETURN_REQUESTED $RETURNING] } } );
        while ( my $order = $rs->next ) {
            my $parcel = $order->order_parcel;
            next unless $parcel;

            my $waybill = $parcel->waybill;
            next unless $waybill;

            my $return_waybill = $parcel->return_waybill;
            next if $return_waybill;

            my $tracker = Parcel::Track->new( $self->driver, $waybill );
            my $result = $tracker->track;
            next unless $result;

            my $html = shift @{ $result->{htmls} ||= [] };
            ($return_waybill) = $html =~ /반품:(\d+)/;

            $parcel->update( { return_waybill => $return_waybill } );
            $self->app->update_status( $order, $RETURNING );
            printf(
                "[%d]: %s -> %s", $order->id, $OpenCloset::Constants::Status::LABEL_MAP{$RETURN_REQUESTED},
                $OpenCloset::Constants::Status::LABEL_MAP{$RETURNING}
            );

            sleep(1);
        }

        sleep( 60 * 60 ); # 1시간마다
    }
}

1;
