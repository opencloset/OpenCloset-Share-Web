package OpenCloset::Share::Web::Controller::Sms;
use Mojo::Base 'Mojolicious::Controller';

=head1 METHODS

=head2 create

    # sms.create
    POST /sms

=cut

sub create {
    my $self = shift;

    return unless $self->admin_auth;

    my $v = $self->validation;
    $v->required('to')->like(qr/^01\d{9}/);
    $v->required('text');

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter Validation Failed: ' . join( ', ', @$failed ) );
    }

    my $to   = $v->param('to');
    my $text = $v->param('text');

    my $sms = $self->sms( $to, $text );
    return $self->error( 500, 'Failed to send a sms' ) unless $sms;

    $self->render( json => { $sms->get_columns } );
}

1;
