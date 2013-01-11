#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Lingua::EN::AutoReview' ) || print "Bail out!\n";
}

Lingua::EN::AutoReview->new( verbose => 1)
	->analyse(eval { local $/; <DATA> })
	->prettyprint;

__DATA__
lah blah blah. dog eat cat worl... but no

---

The man -- whom none had cared to listen to, was now gone.