#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Data::Event::Processor' ) || print "Bail out!\n";
}

diag( "Testing Data::Event::Processor $Data::Event::Processor::VERSION, Perl $], $^X" );
