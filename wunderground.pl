#!/usr/bin/perl
use strict;
use warnings;
use WWW::Wunderground::API;
use DaZeus;
use v5.14;
use open qw(:encoding(UTF-8) :std);
use utf8;

my ($socket, $default_location) = @ARGV;
if(!$socket) {
	die "Usage: $0 socket [default_location]\n";
}

my $dazeus = DaZeus->connect($socket) or die $!;
sub reply {
        my ($response, $network, $sender, $channel) = @_;

        if ($channel eq $dazeus->getNick($network)) {
                $dazeus->message($network, $sender, $response);
        } else {
                $dazeus->message($network, $channel, $response);
        }
}

$dazeus->subscribe_command("weather" => sub {
	my ($dazeus, $network, $sender, $channel, $command, $args) = @_;
	my $location = $args ? $args : $default_location;
	if(!$location) {
		reply("Usage: weather <location>", $network, $sender, $channel);
		return;
	}

	my $weather = WWW::Wunderground::API->new(location => $location, auto_api => 1);
	if(!$weather) {
		reply("Couldn't get weather info for '$location': $@\n", $network, $sender, $channel);
		return;
	}
	# explicitly update conditions by asking for temp_c
	$weather->temp_c;
	$weather = $weather->conditions();
	if(!$weather) {
		reply("Couldn't get weather info for '$location': $@\n", $network, $sender, $channel);
		return;
	}
	# Nijmegen: Overcast, 11ºC, wind 5 km/h SSE, 91% humidity
	$weather->{'full_location'} = $weather->{'display_location'}{'full'};
	$weather->{'wind_kmh'} = $weather->{'wind_mph'} * 1.609344;
	reply(sprintf("%s: %s, %.1f ºC, wind %.1f km/h %s, %s humidity",
		map { $weather->{$_} } qw/full_location weather temp_c wind_kmh wind_dir relative_humidity/),
		$network, $sender, $channel);
});
while($dazeus->handleEvents()) {}
