package Lingua::EN::AutoReview::Error;

use 5.014;
use strict;
use Moose;

has locations => (
	is  => 'rw',
	isa => 'ArrayRef[ArrayRef[Int]]',
	traits => [ 'Array' ],
	default => sub { [] },
	handles => {
		all      => 'elements',
		in_text  => 'count',
		found_at => 'push',
	},
);

has msg => (
	is       => 'rw',
	isa      => 'Str',
	default  => 'No explanation given.',
	required => 1,
);

has verbose_msg => (
	is  => 'rw',
	isa => 'Str',
	predicate => 'has_verbose_msg',
);

=head1 NAME

Lingua::EN::AutoReview::Error - Error information for Lingua::EN::AutoReview

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2013 Cameron Thornton.

This program is free software; you can redistribute it and/or modify it
under the terms as perl itself.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;