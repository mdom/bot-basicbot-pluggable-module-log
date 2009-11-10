#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 17;
use File::Temp qw(tempdir);
use Bot::BasicBot::Pluggable;

BEGIN {
	*CORE::GLOBAL::localtime = sub  { return (37,21,9,11,2,109,3,69,0) };
}

use Bot::BasicBot::Pluggable::Module::Log;

my $dir = tempdir( CLEANUP => 1 );

sub last_log {
	my ($file,undef) = glob("$dir/*.log"); # this should never be more than one file!
	return '' if !$file;
	open(my $log,'<',$file) or die $file . $!;
	chomp( my $line = <$log> );
	unlink $file or die $!;
	return $line;
}

my $bot = Bot::BasicBot::Pluggable->new(
  channels => [ '#botzone' ],
  nick     => 'TestBot',
  store    => Bot::BasicBot::Pluggable::Store->new(),
);

my $module = Bot::BasicBot::Pluggable::Module::Log->new(Bot => $bot);

$module->set('user_log_path',$dir);
$module->set('user_link_current',0);

my $message            = { channel => '#botzone', body => 'Foobar!', who => 'bob'                           };
my $message_from_bot   = { channel => '#botzone', body => 'Foobar!', who => 'TestBot'                       };
my $message_to_bot     = { channel => '#botzone', body => 'Foobar!', who => 'bob',     address => 'TestBot' };
my $foobarless_message = { channel => '#botzone', body => 'Bar!',    who => 'bob',     address => 'TestBot' };
my $query              = { channel => 'msg',      body => 'Foobar!', who => 'bob'                           };

$module->seen($message);
is(last_log(),'[#botzone 09:21:37] <bob> Foobar!','sent normal message to channel');

$module->chanjoin($message);
is(last_log(),'[#botzone 09:21:37] JOIN: bob','log channel join');

$module->chanpart($message);
is(last_log(),'[#botzone 09:21:37] PART: bob','log channel part');

$module->set('user_ignore_joinpart',1);

$module->chanjoin($message);
is(last_log(),'','ignore channel join');

$module->chanpart($message);
is(last_log(),'','ignore channel part');


$module->seen($message_from_bot);
is(last_log(),'','ignore message from bot');

$module->seen($message_to_bot);
is(last_log(),'','ignore message to bot');

$module->set('user_ignore_bot',0);

$module->seen($message_from_bot);
is(last_log(),'[#botzone 09:21:37] <TestBot> Foobar!','log message from bot');

$module->seen($message_to_bot);
is(last_log(),'[#botzone 09:21:37] <bob> TestBot: Foobar!','log message to bot');

is($module->help(),'Logs all activities in a channel.','expected help message');

$module->set('user_ignore_pattern', 'Foobar');
$module->seen($message);
is(last_log(),'','ignore message matching Foobar');

$module->emoted($query,0);
is(last_log(),'','ignore emotes matching Foobar');

$module->seen($foobarless_message);
is(last_log(),'[#botzone 09:21:37] <bob> TestBot: Bar!','log message without Foobar');

$module->set('user_ignore_pattern', undef);

$module->seen($query);
is(last_log(),'','ignore query');

$module->set('user_ignore_query',0);
$module->set('user_ignore_bot',0);
$module->seen($query);
is(last_log(),'[msg 09:21:37] <bob> Foobar!','log query');

$module->emoted($query,0);
is(last_log(),'[msg 09:21:37] * bob Foobar!','emoting');

$module->emoted($query,1);
is(last_log(),'','ignore emoting with higher priority than 0');

1;
