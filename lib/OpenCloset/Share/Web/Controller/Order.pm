package OpenCloset::Share::Web::Controller::Order;
use Mojo::Base 'Mojolicious::Controller';

use OpenCloset::Constants::Category;

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 add

    # order.add
    GET /order/new

=cut

sub add {
    my $self = shift;
}

=head2 create

    # order.create
    POST /order

=cut

sub create {
    my $self = shift;

    my @categories;
    for my $c ( $JACKET, $PANTS, $SHIRT, $SHOES, $TIE ) {
        my $p = $self->param("category-$c") || '';
        push @categories, $c if $p eq 'on';
    }

    $self->session( order => { categories => [@categories] } );
    # 주문서를 만들자 그리고 UUID 로 연결?

    $self->redirect_to('order.recommend');
}

1;
