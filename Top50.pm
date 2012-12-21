package Top50;
use strict;
use warnings;

=head1 NAME

TopN

=head1 DESCRIPTION

This class keeps counts. You can add a numeric value to is and it will keep track of how ofter you
have done so.

It will also be able to return the top 50 for any n without much work.

Additions will expire in a given number of seconds. This number is the same for all aditions.

=head1 DATA STRUCTURE

UPDATE

Internally it keeps two data structures. The first counts is just a hash from value to the current
count to be able to return teh current counts quickly, but it is also used as a lookup internally.

The second data structure is a hash that has the the current counts that have values associated
with them as keys. The values are again hashes with those values as keys. The values don't
matter. The hash is just for quick deletion.

Finally a list is kept of when each element needs to expire. The list is kept in insertion order
and since the duration is teh same for each addition this is also the order in which they need to
expire.

=head1 CAVEAT

This is not thread-safe.

=head1 METHODS

=over

=item new( $expire_in , $expire_on_add )

This creates a new counting structure. $expire_in is the number of seconds before an addition
expires. $expire_on_add is thr maximum number of expires to execute on each add and it defaults to
3.

=cut

sub new {
    my ($class, $expire_in, $expire_on_add) = @_;
    $class = ref($class) || $class;
    $expire_on_add ||= 3;

    my $self = {
          counts        => {}, # lookup table from value to count
          top50         => [], # top 50 list ordered in decreasing count
          expire        => [], # list if values and when to expire them
          expire_in     => $expire_in,
          expire_on_add => $expire_on_add,
    };

    return bless $self, $class;
};

=item add( $value )

Adds the value

It also processses a few expiries.

=cut 

sub add {
    my ($self, $value) = @_;

    my $counts = $self->{counts};
    my $count = $counts->{$value} || 0;

    if ( $count ) {
        $counts->{$value}++;
    } else {
        $counts->{$value} = 1;
    };

    my $expire = $self->{expire};
    push(@$expire, [$self->{expire_in} + time(), $value ]);

    $self->expire( $self->{expire_on_add} );

    $self->_update_top50($count+1, $value);

    return;
};

sub _update_top50 {
    my ($self, $count, $value) = @_;

    my $top50 = $self->{top50};
    my $counts = $self->{counts};

    # heap would be faster?

    if (scalar(@$top50) < 50 ) {
        push( @$top50, $value );
        @$top50 = sort @$top50;
    } elsif ( $counts->{ $top50->[49] } < $count ) {
        $top50->[49] = $value;
        my $i = 49;
        while ( $i>0 and $counts->{ $top50->[$i-1] } < $counts->{ $top50->[$i] } ) {
            my $swap = $top50->[$i-1];
            $top50->[$i-1] = $top50->[$i];
            $top50->[$i] = $swap;
            $i--;
        }
    }

};

=item top( $n )

Returns the top $n values added.

The values returned are ordered by number off ads. The order of values with the same number of
adds is not fixed, so you may get differences in order and even in values each call but all
answeres will be equally valid.

=cut

sub top {
    my ($self, $n) = @_;

    $self->expire();

    return @{ $self->{top50} };
};

=item expire($n)

Expire up to $n items. If $n is not defined it will expire as much as possible.
Returns the number of items actually expired.

=cut

sub expire {
    my ($self, $limit) = @_;

    my $counts = $self->{counts};
    my $expire = $self->{expire};

    my $times = 0;
    while ( @$expire ) {
        last if defined($limit) and $times >= $limit;
        last if $expire->[0]->[0] > time();
        my $expire_value = shift(@$expire)->[1];
        my $expire_count = $counts->{$expire_value};
        $counts->{$expire_value}--;
        $times++;
    }

    return $times;
};

=item get($value)

Returns the current count for $value;

=cut

sub get {
    my ($self, $value) = @_;

    return $self->{counts}->{$value};
};


=item size()

Returns the number of different element a count is kept for. So if you count 1,2,1,3,2,1 it would
return 3 for 1,2 and 3.

=cut

sub size {
    my ($self) = @_;

    return scalar(keys(%{$self->{counts}}));
};

=item expire_size()

Returns the number of count actions yet to be expired.

=cut

sub expire_size {
    my ($self) = @_;

    return scalar(@{$self->{expire}});
};

1;

package main;
use strict;
use warnings;

sub test {
    my $counts = Top50->new(60,1);
    $counts->add( int(rand(1_000_000+1)) ) for 1 .. 10_000_000;

    foreach my $value ( $counts->top(50) ) {
        print "$value added " . $counts->get($value) . " times\n";
    };
    print "Done\n";
};

test();

1;
