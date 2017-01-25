package OpenCloset::Share::Web::Controller::Root;
use Mojo::Base 'Mojolicious::Controller';

use OpenCloset::Constants::Status qw/$RENTAL/;

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 index

    # index
    GET /

=cut

sub index {
    my $self      = shift;
    my $user      = $self->stash('user');
    my $user_info = $self->stash('user_info');

    my $failed = $self->check_measurement( $user, $user_info );
    my $orders = $self->schema->resultset('Order')->search( { user_id => $user->id }, { order_by => { -desc => 'id' } } );
    $self->render( failed => $failed, orders => $orders );
}

=head2 search

    # search
    GET /search?q=xxx

=cut

sub search {
    my $self = shift;
    my $q    = $self->param('q');

    return $self->error( 400, "Empty query" ) unless $q;

    my $clothes = $self->schema->resultset('Clothes')->find( { code => sprintf( '%05s', $q ) } );
    return $self->error( 404, "Clothes not found: $q" ) unless $clothes;

    my $status_id = $clothes->status_id;
    if ( $status_id == $RENTAL ) {
        my $detail = $clothes->order_details( { status_id => $status_id }, { rows => 1, order_by => { -desc => 'create_date' } } )->single;
        $self->redirect_to( 'order.purchase', order_id => $detail->order_id );
    }
    else {
        $self->redirect_to( '/clothes/' . $clothes->code );
    }
}

=head2 terms

    GET /terms

=cut

sub terms { }

=head privacy

    GET /privacy

=cut

sub privacy { }

1;
