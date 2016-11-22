#!/usr/bin/perl
use strict;
use warnings;
use Weather::Underground;
use DaZeus;

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
	my $weather = Weather::Underground->new(
		place => $location,
	);
	if(!$weather) {
		reply("Couldn't get weather info for '$location': $@\n", $network, $sender, $channel);
		return;
	}
	$weather = $weather->get_weather();
	if(!$weather) {
		reply("Couldn't get weather info for '$location': $@\n", $network, $sender, $channel);
		return;
	}
	if(!@$weather) {
		reply("Couldn't get weather info for '$location': no such place\n", $network, $sender, $channel);
		return;
	}
	if(@$weather > 1) {
		my $locations = join ", ", map { $_->{'place'} } @$weather;
		if(length($locations) > 100) {
			$locations = substr($locations, 0, 100) . "...";
		}
		reply("Which of these locations did you mean? $locations", $network, $sender, $channel);
		return;
	}
	$weather = $weather->[0];
	# Nijmegen: Overcast, 11ºC, wind 5 km/h SSE, 91% humidity, sunset 4:36 PM CET
	reply(sprintf("%s: %s, %.1fºC, wind %.1f km/h %s, %02d%% humidity, sunset %s",
		map { $weather->{$_} } qw/conditions celsius wind_kilometersperhour wind_direction humidity sunset/),
		$network, $sender, $channel);
});
while($dazeus->handleEvents()) {}
