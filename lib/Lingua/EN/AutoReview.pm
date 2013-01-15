package Lingua::EN::AutoReview;

use utf8;
use 5.014;
use strict;
use warnings FATAL => 'all';

our $VERSION = 'v0.1.4';

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

=cut

use Moose;
use Lingua::EN::AutoReview::Error;
use File::ShareDir;

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
	default => sub {[
		\&_ascii_dashes,
		\&_start_sentence_with_capital_letter,
	]},
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
		all_errors   => 'elements',
		add_error    => 'push',
		clear_errors => 'clear',
	},
);

sub _share_file_lines ($) {
	my $fn = shift;
	my @lines;

	open R, "<", File::ShareDir::module_file(__PACKAGE__, $fn)
						or die "Cannot open $fn: $!";
	while(<R>) {
		chomp;
		next if /^#/;
		next unless $_;
		push @lines, $_;
	}
	close R;

	return \@lines;
}

sub _rule_by_regex {
	my( $error, $lines, $pattern ) = @_;

	for(my $i = 0; $i <= $#$lines; $i++) {
		while( $lines->[$i] =~ /$pattern/g ) {
			$error->found_at([$i, $-[0], $+[0] - $-[0]]);
		}
	}
}

=head1 METHODS

=head2 analyse

Analyses a string of English prose.

=cut

sub analyse ($) {
	my( $self, $text ) = @_;

	# Clear data from previous analyses in case multiple texts
	# are checked with the same AutoReview object
	$self->clear_errors;

	# Extract lines
	$self->lines([ split /\r\n|\n\r|\n|\r/, $text ]);

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
				my $pos = $_->[1] - 5;
				my $len = $_->[2] + 10;

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

	my $abbrev = _share_file_lines("abbreviations.en");

	# Variable-length look behind searches aren't implemented in Perl 5,
	# but we can work around this by reversing everything, since variable-length
	# look ahead searches *are* implemented. A bit of a pain in the neck, but it
	# gets the job done.
	$abbrev = join "|", map { quotemeta reverse $_ } @$abbrev;

	my $pattern = qr`
		\p{Lowercase}
		[^\w\.]*?
		(?:\.|$)
		(?!$abbrev)
	`x;

	for(my $i = 0; $i <= $#$lines; $i++) {
		my $enil = reverse $lines->[$i];
		my $length = length $enil;
		while( $enil =~ /$pattern/g ) {
			$error->found_at([$i, $length - $-[0], $+[0] - $-[0]])
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

	my $pattern = qr`
		(?<=[^\-])
		-{2,}
	`x;

	_rule_by_regex($error, $lines, $pattern);
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
under the same terms as perl itself.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;