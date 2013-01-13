#!/usr/bin/env perl

use strict;
use v5.14;

use Lingua::EN::AutoReview;
use Getopt::Long;
use open qw( :encoding(UTF-8) :std );

my $verbose = 0;
my $lang = 'GB';

GetOptions( "lang=s" => \$lang, verbose => \$verbose );

my $in = '';

my $fn = shift;
if( -e $fn && -r $fn ) {
	open R, "<", $fn;
	$in = eval { local $/; <R> };
	close R;
}
else {
	$in = eval { local $/; <STDIN> };
}

Lingua::EN::AutoReview->new( verbose => $verbose, lang => $lang )
	->analyse($in)
	->prettyprint;

__END__