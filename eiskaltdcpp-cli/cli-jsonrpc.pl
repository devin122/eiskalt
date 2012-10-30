#!/usr/bin/perl
#
# Copyright (c) 2011 Dmitry Kolosov <onyx@z-up.ru>
#
# Redistribution and use in source and binary forms, with or without modification, 
# are permitted provided that the following conditions are met:
#	1. Redistributions of source code must retain the above copyright notice,
#	this list of conditions and the following disclaimer.
#	2. Redistributions in binary form must reproduce the above copyright 
#	notice, this list of conditions and the following disclaimer in the 
#	documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
#
use strict;
use warnings;
use 5.012;
use JSON::RPC::Legacy::Client;
use Term::ShellUI;
use Data::Dump qw[dump];
use Getopt::Long;
use Env qw[$XDG_CONFIG_HOME $HOME];

# use non-standart paths
BEGIN {
    unshift @INC, 
	 "$XDG_CONFIG_HOME/eiskaltdc++",
	 "$HOME/.config/eiskaltdc++/",
	 "/usr/local/share/eiskaltdcpp/cli",
	 "/usr/share/eiskaltdcpp/cli"
}

# preparing terminal
use utf8;
use locale;
binmode STDOUT, ':utf8';

# configuration
our %config;
$config{version}=0.2;
$config{revision}=17062012;
require "cli-jsonrpc-config.pl";
my $version,my $help;
GetOptions ('V|version' => \$version, 'h|help' => \$help);
if ($version)
{
	print("Command line JSON-RPC interface version.revision: $config{version}.$config{revision}\n"); exit(1);
}
if ($help)
{
	print(  "Using:
\teiskaltdcpp-jcli
\teiskaltdcpp-jcli <Key>
This is command line JSON-RPC interface for eiskaltdcpp-daemon written on perl.
EiskaltDC++ is a cross-platform program that uses the Direct Connect and ADC protocol.

Keys:
\t-h, --help\t Show this message
\t-V, --version\t Show version string\n");
	exit(1);
}
print("Configuration:\n");
foreach (keys %config)
{
	print("$_: $config{$_}\n");
}

# rest variables
my $obj;
$obj->{'jsonrpc'} = $config{jsonrpc};
my $res;

# creating and configuring client
my $client = new JSON::RPC::Legacy::Client;
$client->version("2.0");
$client->ua->timeout(10);
#$client->ua->credentials('http://127.0.0.1:3121', 'jsonrpc', 'user' => 'password');

# creating shell
my $term = new Term::ShellUI(commands => get_commands(), history_file => $config{hist_file}, history_max => $config{hist_max});
$term->prompt("$config{prompt}");
$term->run();

sub get_commands
{
	return
	{
		"magnet.add" =>
		{
			desc => "Add a magnet to download queue, and fetch it to download directory. Parameters: magnet, download directory",
			args => sub { shift->complete_onlydirs(@_) },
			minargs => 2,
			maxargs => 2,
			proc => \&magnetadd
		},
		"daemon.stop" =>
		{
			desc => "Disconnect from hubs and exit, no params",
			proc => \&daemonstop
		},
		"hub.add" =>
		{
			desc => "Add a new hub and connect. Parameters: huburl, encoding",
			minargs => 2,
			maxargs => 2,
			proc => \&hubadd
		},
		"hub.del" =>
		{
			desc => "Disconnect hub and delete from autoconnect. Parameters: huburl",
			# add autocomplete from list of connected hubs
			minargs => 1,
			maxargs => 1,
			proc => \&hubdel
		},
		"hub.say" =>
		{
			desc => "Send a public message to hub. Parameters: huburl, message",
			# add autocomplete from list of connected hubs 
			#args => sub { grep { !/^\.?\.$/ } shift->complete_onlydirs(@_) },
			minargs => 2,
			maxargs => 2,
			proc => \&hubsay
		},
		"hub.pm" =>
		{
			desc => "Send a private message to nick on hub. Parameters: huburl, nick, message",
			# add autocomplete from connected hubs and nicks
			#args => sub { grep { !/^\.?\.$/ } shift->complete_onlydirs(@_) },
			minargs => 3,
			maxargs => 3,
			proc => \&hubpm
		},
		"hub.list" =>
		{
			desc => "Get a list of hubs, configured to connect to. Parameters: separator",
			#args => sub { grep { !/^\.?\.$/ } shift->complete_onlydirs(@_) },
			#minargs => 1,
			maxargs => 1,
			proc => \&hublist
		},
		"share.add" =>
		{
			desc => "Add a directory to share as virtual name. Parameters: directory, virtual name",
			args => sub { shift->complete_onlydirs(@_) },
			minargs => 2,
			maxargs => 2,
			proc => \&shareadd
		},
		"share.rename" =>
		{
			desc => "Give a new virtual name to shared directory. Parameters: directory, virtual name",
			args => sub { shift->complete_onlydirs(@_) },
			minargs => 2,
			maxargs => 2,
			proc => \&sharerename
		},
		"share.del" =>
		{
			desc => "Unshare directory with virtual name. Parameters: Parameters: virtual name",
			minargs => 1,
			maxargs => 1,
			proc => \&sharedel
		},
		"share.list" =>
		{
			desc => "Get a list of shared directories. Parameters: separator",
			maxargs => 1,
			proc => \&sharelist
		},

		"share.refresh" =>
		{
			desc => "Refresh a share, hash up new files. Parameters: none",
			proc => \&sharerefresh
		},
		"list.download" =>
		{
			desc => "Download a file list from nick on huburl. Parameters: huburl, nick",
			minargs => 2,
			maxargs => 2,
			proc => \&listdownload
		},
		"hub.getchat" =>
		{
			desc => "Get last public chat messages. Parameters: huburl, separator",
			minargs => 1,
			maxargs => 2,
			proc => \&hubgetchat
		},
		"search.send" =>
		{
			desc => "Start hub search. Parameters: search string",
			minargs => 1,
			maxargs => 1,
			proc => \&searchsend
		},
		"search.getresults" =>
		{
			desc => "Get search results from all hubs (or only from specified). Parameters: huburl",
			maxargs => 1,
			proc => \&searchgetresults
		},
		"show.version" =>
		{
			desc => "Show daemon version. Parameters: none",
			proc => \&showversion
		},
		"show.ratio" =>
		{
			desc => "Show client ratio. Parameters: none",
			proc => \&showratio
		},
		"queue.setpriority" =>
		{
			desc => "Set download queue priority. Parameters: target, proirity. Priority is an integer from 0(paused) to 3(high)",
			minargs => 2,
			maxargs => 2,
			proc => \&qsetprio
		},
		"queue.move" =>
		{
			desc => "Move queue item from source to target. Parameters: source, target",
			minargs => 2,
			maxargs => 2,
			proc => \&qmove
		},
		"queue.remove" =>
		{
			desc => "Delete queue item by target. Parameters: target",
			minargs => 1,
			maxargs => 1,
			proc => \&qremove
		},
		"queue.list" =>
		{
			desc => "Show queue, including all targets. Parameters: none",
			proc => \&qlist
		},
		"queue.listtargets" =>
		{
			desc => "Show  all targets. Parameters: none",
			proc => \&qlisttargets
		},
		"search.clear" =>
		{
			desc => "Clear search results. Parameters: huburl",
			maxargs => 1,
			proc => \&searchclear
		},
		"queue.getsources" =>
		{
			desc => "Show sources for specified target. Parameters: target, separator",
			minargs => 1,
			maxargs => 2,
			proc => \&qgetsources
		},
		"hash.status" =>
		{
			desc => "Show hashing process status. Parameters: none",
			proc => \&hashstatus
		},
		"hash.pause" =>
		{
			desc => "Pause hashing process. Parameters: none",
			proc => \&hashpause
		},
		"methods.list" =>
		{
			desc => "List all jsonrpc methods available. Parameters: none",
			proc => \&methodslist
		},
		"queue.matchlists" =>
		{
			desc => "Description here. Parameters: none",
			proc => \&qmatchlists
		},
		# last
		"prompt" =>
		{
			desc => "Set custom prompt",
			minargs => 1,
			maxargs =>1,
			proc => sub { $term->prompt(shift) }
		},
		"exec" =>
		{
			desc => "Execute shell command",
			args => sub { shift->complete_files(@_); },
			minargs => 1,
			proc => sub { system(shift) }
		},
		"quit" => 
		{
			desc => "Quit this program", 
			maxargs => 0,
			method => sub { shift->exit_requested(1); }
		},
		"exit" => { alias => 'quit' },
		'' =>
		{
	  		proc => "No command here by that name\n",
			desc => "No help for unknown commands."
		},
		"help" => 
		{ 
			desc => "Print helpful information",
			args => sub { shift->help_args(undef, @_); },
			method => sub { shift->help_call(undef, @_); } 
		}
	}
}

sub magnetadd($$)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'magnet.add';
	$obj->{'params'}->{'magnet'}=$_[0];
	$obj->{'params'}->{'directory'}=$_[1];
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub daemonstop()
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'daemon.stop';
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
}

sub hubadd($$)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'hub.add';
	$obj->{'params'}->{'huburl'}=$_[0];
	$obj->{'params'}->{'enc'}=$_[1];
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub hubdel($)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'hub.del';
	$obj->{'params'}->{'huburl'}=$_[0];
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub hubsay($$)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'hub.say';
	$obj->{'params'}->{'huburl'}=$_[0];
	$obj->{'params'}->{'message'}=$_[1];
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub hubpm($$$)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'hub.pm';
	$obj->{'params'}->{'huburl'}=$_[0];
	$obj->{'params'}->{'nick'}=$_[1];
	$obj->{'params'}->{'message'}=$_[2];
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub hublist($)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'hub.list';
	$obj->{'params'}->{'separator'}=($_[0] || $config{'separator'});
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub shareadd($$)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'share.add';
	$obj->{'params'}->{'directory'}=$_[0];
	$obj->{'params'}->{'virtname'}=$_[1];
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub sharerename($$)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'share.rename';
	$obj->{'params'}->{'directory'}=$_[0];
	$obj->{'params'}->{'virtname'}=$_[1];
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub sharedel($)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'share.del';
	$obj->{'params'}->{'directory'}=$_[0];
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub sharelist($)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'share.list';
	$obj->{'params'}->{'separator'}=($_[0] || $config{'separator'});
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub sharerefresh()
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'share.refresh';
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
}

sub listdownload($$)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'list.download';
	$obj->{'params'}->{'huburl'}=$_[0];
	$obj->{'params'}->{'nick'}=$_[1];
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub hubgetchat($$)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'hub.getchat';
	$obj->{'params'}->{'huburl'}=$_[0];
	$obj->{'params'}->{'separator'}=($_[1] || $config{'separator'});
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub searchsend($)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'search.send';
	$obj->{'params'}->{'searchstring'}=$_[0];
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub searchgetresults($)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'search.getresults';
	if (defined($_[0])) {$obj->{'params'}->{'huburl'}=$_[0]};
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub searchclear($)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'search.clear';
	if (defined($_[0])) {$obj->{'params'}->{'huburl'}=$_[0]};
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub showversion()
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'show.version';
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
}

sub showratio()
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'show.ratio';
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n");
			print("Ratio:\t\t".dump($res->content->{ratio})."\n");
			print("Upload:\t\t".dump($res->content->{up})."\n");
			print("Download:\t".dump($res->content->{down})."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
}

sub qsetprio($$)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'queue.setpriority';
	$obj->{'params'}->{'target'}=$_[0];
	$obj->{'params'}->{'priority'}=$_[1];
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub qmove($$)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'queue.move';
	$obj->{'params'}->{'source'}=$_[0];
	$obj->{'params'}->{'target'}=$_[1];
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub qremove($)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'queue.remove';
	$obj->{'params'}->{'target'}=$_[0];
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub qlist()
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'queue.list';
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
}

sub qlisttargets()
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'queue.listtargets';
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
}

sub qgetsources($$)
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'queue.getsources';
	$obj->{'params'}->{'target'}=$_[0];
	$obj->{'params'}->{'separator'}=($_[1] || $config{'separator'});
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
	delete($obj->{'params'});
}

sub hashstatus()
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'hash.status';
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
}

sub hashpause()
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'hash.pause';
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
}

sub methodslist()
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'methods.list';
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
}

sub qmatchlists()
{
	$obj->{'id'} = int(rand(2**16));
	$obj->{'method'} = 'queue.matchlists';
	if ($config{debug} > 0) { print("===Request===\n".dump($obj)."\n") };
	$res = $client->call($config{eiskaltURL}, $obj);
	if ($res)
	{
		if ($res->is_error) 
		{
			print("===Error===\n".dump($res->error_message)."\n");
		}
		else
		{
			print("===Reply===\n".dump($res->result)."\n");
		}
	}
	else
	{
		print $client->status_line;
	}
}


__END__

=pod

# known methods as for 0.2.17062012
# grep "AddMethod" eiskaltdcpp-daemon/ServerThread.cpp | egrep -o "std::string\(.*\)"
+magnet.add
+daemon.stop
+hub.add
+hub.del
+hub.say
+hub.pm
+hub.list
+hub.getchat
+share.add
+share.rename
+share.del
+share.list
+share.refresh
+list.download
+search.send
+search.getresults
+search.clear
+show.version
+show.ratio
+queue.setpriority
+queue.move
+queue.remove
+queue.listtargets
+queue.list
+queue.getsources
+hash.status
+hash.pause
+methods.list
+queue.matchlists

=cut
