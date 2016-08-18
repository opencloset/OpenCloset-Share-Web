package OpenCloset::Share::Web::Controller::Address;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 create

    POST /address

=cut

sub create {
    my $self = shift;
    my $user = $self->stash('user');

    my $v = $self->validation;
    $v->required('address1');
    $v->required('address2');
    $v->required('address3');

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter validation failed: ' . join( ', ', @$failed ) );
    }

    my $address1 = $v->param('address1');
    my $address2 = $v->param('address2');
    my $address3 = $v->param('address3');

    my $address = $self->schema->resultset('UserAddress')->create(
        {
            user_id  => $user->id,
            address1 => $address1,
            address2 => $address2,
            address3 => $address3,
        }
    );

    return $self->error( 500, 'Failed to create a new address' ) unless $address;

    $self->render( json => { $address->get_columns }, status => 201 );
}

=head2 update_address

    PUT /address/:address_id

=cut

sub update_address {
    my $self       = shift;
    my $user       = $self->stash('user');
    my $address_id = $self->param('address_id');

    my $address = $self->schema->resultset('UserAddress')->find( { id => $address_id } );
    return $self->error( 404, "Not found user address: $address_id" ) unless $address;
    return $self->error( 400, "Permission denied" ) if $user->id != $address->user_id;

    my $v = $self->validation;
    $v->optional('address1');
    $v->optional('address2');
    $v->optional('address3');
    $v->optional('address4');

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter Validation Failed: ' . join( ', ', @$failed ) );
    }

    my $input = $v->input;
    map { delete $input->{$_} } qw/name pk value/; # delete x-editable params

    $address->update($input);
    $self->render( json => { $address->get_columns }, status => 201 );
}

=head2 delete_address

    DELETE /address/:address_id

=cut

sub delete_address {
    my $self       = shift;
    my $user       = $self->stash('user');
    my $address_id = $self->param('address_id');

    my $address = $self->schema->resultset('UserAddress')->find( { id => $address_id } );
    return $self->error( 404, "Not found user address: $address_id" ) unless $address;
    return $self->error( 400, "Permission denied" ) if $user->id != $address->user_id;

    $address->delete;
    $self->render( json => {}, status => 201 );
}

1;
