package Lingua::EN::AutoReview;

use 5.014;
use strict;
use warnings FATAL => 'all';

our $VERSION = 'v0.1.1';

use Moose;
use Lingua::EN::AutoReview::Error;

has lang => (
	is  => 'rw',
	isa => 'Str',
	default => 'US',
);

has verbose => (
	is  => 'rw',
	isa => 'Bool',
	default => 0,
	required => 1,
);

has lines => (
	is      => 'rw',
	isa     => 'ArrayRef[Str]',
	traits  => [ 'Array' ],
	handles  => {
		line => 'accessor',
	},
);

has rules => (
	is      => 'rw',
	isa     => 'ArrayRef[CodeRef]',
	traits  => [ 'Array' ],
	default => sub {
		my @rules; 

		# A bit hacky; reads this file to find the default rules
		my $fn = __PACKAGE__; 
		$fn =~ s/::/\//g; 
		$fn =~ s/$/.pm/;

		open CODE, "<", $INC{$fn};
		while(<CODE>) {
			if( /^sub (_[a-zA-Z0-9_]+)/ ) {
				push @rules, \&$1;
			}
		}
		close CODE;

		return \@rules;
	},
	handles => {
		all_rules => 'elements',
		add_rule  => 'push',
	}
);

has errors => (
	is      => 'rw',
	isa     => 'ArrayRef[Lingua::EN::AutoReview::Error]',
	traits  => [ 'Array' ],
	default => sub { [] },
	handles => {
		all_errors => 'elements',
		add_error  => 'push',
	},
);

=head1 NAME

Lingua::EN::AutoReview - Identify common errors in English prose

=head1 SYNOPSIS

  use Lingua::EN::AutoReview;
  
  my $r = Lingua::EN::AutoReview->new( lang => 'GB' );

  # Add your own rules if desired
  $r->add_rule(sub {
    my( $error, $lines, $lang ) = @_;
	
    #. . .
  });

  $r->analyse($prose);
  
  $r->prettyprint;

=head1 METHODS

=head2 analyse

Analyses a string of English prose.

=cut

sub analyse ($) {
	my( $self, $text ) = @_;

	# Standardise newlines
	$text =~ s/\r\n/\n/g;
	$text =~ s/\n\r/\n/g;
	$text =~ s/\r/\n/g;

	$self->lines([ split /\n/, $text ]);

	for my $rule ( $self->all_rules ) {
		my $error = Lingua::EN::AutoReview::Error->new;

		$rule->($error, $self->lines, $self->lang);

		$self->add_error($error);
	}

	return $self;
}

=head2 prettyprint

Pretty prints the result of the analysis.

=cut

sub prettyprint {
	my $self = shift;

	# Put two newlines at the end of every print
	local $\ = "\n\n";

	my $n = 0;

	print "Result of analysis\n"
	    . "==================";

	for my $error ( $self->all_errors ) {

		if( $error->in_text ) {

			print $error->msg;
			print $error->verbose_msg if $self->verbose && $error->has_verbose_msg;

			for ( $error->all ) {
				my $line = $self->lines->[ $_->[0] ];

				# Give a little context to the error
				my $pos = $_->[1] - 3;
				my $len = $_->[2] + 6;

				print sprintf "   Line %d - `%s`",
					$_->[0] + 1,
					substr($line, $pos > 0 ? $pos : 0, $len);

				$n++;
			}

		}

	}

	print "Total errors found: $n.";
}

=head1 DEFAULT RULES 

The following things are analysed by default. Check the source for exact implementation.

* Sentences not beginning with capital letters
* Hyphens used instead of dashes

=cut

sub _start_sentence_with_capital_letter {
	my( $error, $lines, $lang ) = @_;

	$error->msg("Sentences should start with a capital letter.");

	for(my $i = 0; $i <= $#$lines; $i++) {

		if( $lines->[$i] =~ /^[^\w\.]*?(\w)/ ) {
			# Check if the first word char on the line is uppercase
			if( $1 ne uc $1 ) {
				$error->found_at([$i, index($lines->[$i], $1), 1]);	
			}
		}

		my $index = -1;

		while( ($index = index $lines->[$i], '.', $index + 1) >= 0 ) {

			# Skip check if this full stop is preceded by another -- we may have an ellipsis
			next if substr($lines->[$i], $index - 1, 1) eq '.';

			my $str = substr $lines->[$i], $index;

			# Check if the full stop is followed by any amount of non-words,
			# followed by a single word character
			if( $str =~ /^(\.[^\w\.]*?(\w))/ ) {

				# Found an error if the word char is not upper case
				if( $2 ne uc $2 ) {
					$error->found_at([$i, $index, length $1]);
				}	
			}

		}

	}
}

sub _ascii_dashes {
	my( $error, $lines, $lang ) = @_;

	$error->msg("Hyphens used in lieu of dashes.");
	$error->verbose_msg(
		"Proper dash characters should be used where appropriate, rather than joining hyphens together. "
		. "See [Wikipedia](http://en.wikipedia.org/wiki/Dash) for information on how to insert them."
	);

	for(my $i = 0; $i <= $#$lines; $i++) {

		# Skip empty lines
		next if $lines->[$i] =~ /^\W+$/;

		my $index = -1;

		while( ($index = index $lines->[$i], '-', $index + 1) >= 0 ) {

			my $str = substr $lines->[$i], $index;

			if( $str =~ /^(-{2,})/ ) {
				$error->found_at([$i, $index, length $1]);

				# Don't keep catching some really long string of hyphens
				$index += length $1;
			}

		}

	}
}

=head1 ADDING RULES

Rules are simply code references.

When the text is analysed, each rule is called in succession. For every rule,
a new L<Lingua::EN::AutoReview::Error> is created and passed to the rule along
with the lines of text to be analysed and the ISO 3166-2 country code for
the text's dialect (typically 'US', 'CA', 'AU', or 'GB').

The first thing each rule should do is add error message(s) to its Error
object that explain the type of error it is checking for. This makes the
prettyprint output more useful to the user. If a certain error requires
verbose explanation (e.g., if there are a lot of false positives), use
a short and verbose error message.

When a rule encounters an error, it should add a notice to the Error object
saying what line it found the error on (as a zero-based index), as well as 
substr arguments for where in that line the error is present.

Putting it all together:

  sub ascii_dashes {
    my( $error, $lines, $lang ) = @_;
    
    $error->msg("Multiple hyphens used in lieu of dashes.");
    $error->verbose_msg(
      "Proper dash characters should be used where appropriate, rather than joining hyphens together. "
      . "See [Wikipedia](http://en.wikipedia.org/wiki/Dash) for information on how to insert them."
    );

    my $dash = $lang eq 'GB' ? ' -- ' : '---';
    my $len = length $dash;

    for(my $i = 0; $i <= $#$lines; $i++) {
      my $index = -$len;
      while( ($index = index $lines->[$i], $dash, $index + $len) >= 0 ) {
        next if $index = 0; #Skip if at start of line
        $error->found_at([$i, $index, $len]);
      }
    }

  }

=head1 AUTHOR

Cameron Thornton E<lt>cthor@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2013 Cameron Thornton.

This program is free software; you can redistribute it and/or modify it
under the terms as perl itself.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;