package OpenCloset::Share::Web::Controller::Root;
use Mojo::Base 'Mojolicious::Controller';

use Data::Pageset;

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
    my $p    = $self->param('p') || 1;
    my $q    = $self->param('q');

    return unless $self->admin_auth;
    return $self->error( 400, "Empty query" ) unless $q;
    return $self->error( 400, "Query is too short: $q" ) if length $q < 2;

    my @or;
    if ( $q =~ m/^[0-9]{1,6}$/ ) {
        push @or, { 'me.id' => $q };
    }
    elsif ( $q =~ /^[0-9\- ]+$/ ) {
        $q =~ s/[- ]//g;
        push @or, { 'user_info.phone' => { like => "%$q%" } };
    }
    elsif ( $q =~ /^[a-zA-Z0-9_\-]+/ ) {
        if ( $q =~ /\@/ ) {
            push @or, { email => { like => "%$q%" } };
        }
        else {
            push @or, { email => { like => "%$q%" } };
            push @or, { name  => { like => "%$q%" } };
        }
    }
    elsif ( $q =~ m/^[ㄱ-힣]+$/ ) {
        push @or, { name => { like => "$q%" } };
    }

    my $rs = $self->schema->resultset('Order')->search(
        {
            online => 1,
            -or    => [@or]
        },
        {
            prefetch => { user  => 'user_info' },
            order_by => { -desc => 'me.update_date' },
            page     => $p,
            rows     => 10
        }
    );

    my $pager   = $rs->pager;
    my $pageset = Data::Pageset->new(
        {
            total_entries    => $pager->total_entries,
            entries_per_page => $pager->entries_per_page,
            pages_per_set    => 5,
            current_page     => $p,
        }
    );

    $self->render(
        q       => $q,
        r       => $rs,
        pageset => $pageset,
    );
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
