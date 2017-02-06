package OpenCloset::Share::Web::Controller::Address;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 create

    POST /address

=cut

sub create {
    my $self      = shift;
    my $user      = $self->stash('user');
    my $user_info = $self->stash('user_info');

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
            name     => $user->name,
            phone    => $user_info->phone,
            address1 => $address1,
            address2 => $address2,
            address3 => $address3,
        }
    );

    return $self->error( 500, 'Failed to create a new address' ) unless $address;

    my %columns = $address->get_columns;
    $columns{phone} = $self->formatted( 'phone', $columns{phone} );
    $self->render( json => \%columns, status => 201 );
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
    $v->optional('recipient');
    $v->optional('phone')->like(qr/^01\d\-?\d{3,4}\-?\d{4}$/);
    $v->optional('address1');
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
    $input->{name} = delete $input->{recipient} if defined $input->{recipient};
    $input->{phone} =~ s/\-//g if $input->{phone};

    $address->update($input);
    my %columns = $address->get_columns;
    $columns{phone} = $self->formatted( 'phone', $columns{phone} );
    $self->render( json => \%columns );
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
    $self->render( json => {} );
}

1;
