package Data::Tabulator;

use warnings;
use strict;

=head1 NAME

Data::Tabulator - Create a table (two-dimensional array) from a list (one dimensional array)

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    my $table = Data::Tabulator->new([ 'a' .. 'z' ], rows => 6);
    my $rows = $table->rows;
    # Returns a the following two-dimensional array:
    # [ 
    #  [ qw/ a b c d e / ],
    #  [ qw/ f g h i j / ],
    #  [ qw/ k l m n o / ],
    #  [ qw/ p q r s t / ],
    #  [ qw/ u v w x y / ],
    #  [ qw/ z/ ],
    # ]

    my $columns = $table->columns;
    # Returns a the following two-dimensional array:
    # [ 
    #  [ qw/ a f k p u z / ],
    #  [ qw/ b g l q v / ],
    #  [ qw/ c h m r w / ],
    #  [ qw/ d i n s x / ],
    #  [ qw/ e j o t y / ],
    # ]

=cut

use POSIX qw/ceil/;
use Sub::Exporter -setup => {
	exports => [
        rows => sub { \&_rows },
        columns => sub { \&_columns },
    ],
};

use Scalar::Util qw/blessed/;

use base qw/Class::Accessor::Fast/;

__PACKAGE__->mk_accessors(qw/_data row_count column_count overlap column_offset pad ready row_accessor column_accessor row_major column_major/);

sub _rows {
    my $data = shift;
    my $rows = shift;
    return __PACKAGE__->new(data => $data, rows => $rows, @_)->rows;
}

sub _columns {
    my $data = shift;
    my $columns = shift;
    return __PACKAGE__->new(data => $data, columns => $columns, @_)->columns;
}

=over 4

=item Data::Tabulator->new

=cut

sub new {
    my $self = bless {}, shift;
    my $data = shift if ref $_[0] eq "ARRAY";
    local %_ = @_;
    $self->data($data || $_{data});
    $self->row_count($_{rows} || $_{row_count});
    $self->column_count($_{columns} || $_{column_count});
    $self->overlap($_{overlap} || 0);
    $self->pad($_{pad} || $_{padding} || 0);
    $self->row_major($_{row_major});
    $self->column_major($_{column_major});
    $self->row_major(1) unless $self->column_major;
    $self->ready(0);
    return $self;
}

#sub __calculate {
#    my $self = shift;

#    my $data = $self->data;
#    my $data_size = @$data;
#    my $row_count = $self->row_count;
#    my $column_count = $self->column_count;
#    my $overlap = $self->overlap;

#    my ($column_offset);

#    if ($row_count) {
#        if ($data_size < $row_count) {
#            $row_count = $data_size;
#            $column_count = 1;
#            $column_offset = 0;
#        }
#        else {
#            $column_offset = $row_count - $overlap;
#            $column_count = int ($data_size / $column_offset) 
#                + ($data_size % $column_offset > $overlap ? 1 : 0)
#        }
#    }
#    elsif ($column_count) {
#        if ($data_size < $column_count) {
#            $column_count = $data_size;
#            $row_count = 1;
#            $column_offset = 1;
#        }
#        else {
#            $column_offset = int ($data_size / $column_count) 
#                + ($data_size % $column_count > $overlap ? 1 : 0);
#            $row_count = $column_offset + $overlap;
#        }
#    }
#    else {
#        $row_count = $data_size;
#        $column_count = 1;
#        $column_offset = 0;
#    }

#    $self->row_count($row_count);
#    $self->column_count($column_count);
#    $self->column_offset($column_offset);
#    $self->_reset;

#    return ($row_count, $column_count);
#}

sub _minor_accessor($$$$$$) {
    my ($major_offset, $major_count, $minor_count, $minor_index, $data, $pad) = @_;

    return () if $minor_index >= $minor_count || $minor_index < 0;
    
    my $data_size = @$data;
    my @minor;
    my $index = $minor_index;

    for (my $major_index = 0; $major_index < $major_count; $major_index++) {
        push(@minor, $index < $data_size ? $data->[$index] : ($pad ? undef : ()));
        $index += $major_offset;
    }

    return \@minor;
}

sub _major_accessor($$$$$$) {
    my ($major_offset, $major_count, $minor_count, $major_index, $data, $pad) = @_;
    
    return () if $major_index >= $major_count || $major_index < 0;

    my $data_size = @$data;
    my ($start, $end, $padding);

    $start = $major_offset * $major_index;
    $end = $major_offset * $major_index + $minor_count - 1;
    $end = $start if $end < $start;
    if ($end >= $data_size) {
        $padding = ($end - $data_size) + 1;
        $end = $data_size - 1;
    }
    return () if $start >= $data_size;

    return [ @$data[$start .. $end], 
             $pad && $padding ? ((undef) x $padding) : () ];
}

sub _calculate {
    my $self = shift;

    my $data = $self->data;
    my $data_size = @$data;
    my $row_count = $self->row_count;
    my $column_count = $self->column_count;
    my $pad = $self->pad;
    my $row_major = $self->row_major;
    my $column_major = $self->column_major;

    my ($row_offset, $column_offset);

    if ($column_major) {
        if ($row_count) {
            if ($data_size < $row_count) {
                $row_count = $data_size;
                $column_count = 1;
                $column_offset = 0;
            }
            else {
                $column_offset = $row_count;
                $column_count = ceil($data_size / $column_offset);
#               $column_count = int ($data_size / $column_offset) +
#                   ($data_size % $column_offset ? 1 : 0);
            }
        }
        elsif ($column_count) {
            if ($data_size < $column_count) {
                $column_count = $data_size;
                $row_count = 1;
                $column_offset = 1;
            }
            else {
                $column_offset = ceil($data_size / $column_count);
#               $column_offset = int ($data_size / $column_count) +
#                   ($data_size % $column_count ? 1 : 0);
                $row_count = $column_offset;
            }
        }
        else {
            $row_count = $data_size;
            $column_count = 1;
            $column_offset = 0;
        }
        $self->row_accessor(sub {
            return _minor_accessor($column_offset, $column_count, $row_count, shift, $data, $pad);
        });
        $self->column_accessor(sub {
            return _major_accessor($column_offset, $column_count, $row_count, shift, $data, $pad);
        });
    }
    else { # Assume row major
        if ($column_count) {
            if ($data_size < $column_count) {
                $column_count = $data_size;
                $row_count = 1;
                $row_offset = 0;
            }
            else {
                $row_offset = $column_count;
                $row_count = ceil($data_size / $row_offset);
            }
        }
        elsif ($row_count) {
            if ($data_size < $row_count) {
                $row_count = $data_size;
                $column_count = 1;
                $row_offset = 1;
            }
            else {
                $row_offset = ceil($data_size / $row_count);
                $column_count = $row_offset;
            }
        }
        else {
            $column_count = $data_size;
            $row_count = 1;
            $row_offset = 0;
        }
        $self->row_accessor(sub {
            return _major_accessor($row_offset, $row_count, $column_count, shift, $data, $pad);
        });
        $self->column_accessor(sub {
            return _minor_accessor($row_offset, $row_count, $column_count, shift, $data, $pad);
        });
    }

    $self->row_count($row_count);
    $self->column_count($column_count);
    $self->column_offset($column_offset);
    $self->_reset;

    return ($row_count, $column_count);
}

=item $table->data

=cut

sub data {
    my $self = shift;
    if (@_) {
        $self->_data(shift);
        $self->_reset;
    }
    return $self->_data;
}

=item $table->width

=cut

sub width {
    my $self = shift;
    $self->_calculate unless $self->ready;
    return ($self->column_count)
}

=item $table->height

=cut

sub height {
    my $self = shift;
    $self->_calculate unless $self->ready;
    return ($self->row_count)
}

=item $table->dimensions

=item $table->geometry

=cut

sub dimensions {
    my $self = shift;
    return ($self->width, $self->height);
}
*geometry = \&dimensions;

=item $table->rows

=cut

sub rows {
    my $self = shift;
    if (@_) {
        return _rows(@_) unless blessed $self;
        $self->row_count(shift);
        $self->_reset;
    }
    else {
        $self->_calculate unless $self->ready;

        my $row_count = $self->row_count;

        return [ map { $self->row($_) } (0 .. $row_count - 1) ];
    }
}

=item $table->columns

=cut

sub columns {
    my $self = shift;
    if (@_) {
        return _columns(@_) unless blessed $self;
        $self->column_count(shift);
        $self->_reset;
    }
    else {
        $self->_calculate unless $self->ready;

        my $column_count = $self->column_count;

        return [ map { $self->column($_) } (0 .. $column_count - 1) ];
    }
}

sub _reset {
    my $self = shift;
    $self->ready(0);
}

=item $table->row

=cut

sub row {
    my $self = shift;
    my $row = shift;

    $self->_calculate unless $self->ready;

    return $self->row_accessor->($row);
}

=item $table->column

=cut

sub column {
    my $self = shift;
    my $column = shift;

    $self->_calculate unless $self->ready;

    return $self->column_accessor->($column);
}

=item $table->as_string

=cut

sub as_string {
    my $self = shift;
    return join "\n", map { join " ", @$_ } @{ $self->rows };
}

=back

=head1 AUTHOR

Robert Krimen, C<< <rkrimen at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-data-tabulate at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Data-Tabulator>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Data::Tabulator

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Data-Tabulator>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Data-Tabulator>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Data-Tabulator>

=item * Search CPAN

L<http://search.cpan.org/dist/Data-Tabulator>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robert Krimen, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Data::Tabulator
