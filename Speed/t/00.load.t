use Test::More tests => 6;

BEGIN {
use_ok( 'Speed::App' );
use_ok( 'Speed::Auth' );
use_ok( 'Speed::Item' );
use_ok( 'Speed::Message' );
use_ok( 'Speed::TransApp' );
use_ok( 'Speed::WrapDB' );
}

diag( "Testing Speed::App $Speed::App::VERSION" );
