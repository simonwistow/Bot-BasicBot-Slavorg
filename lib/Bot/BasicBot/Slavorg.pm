=head1 NAME

Bot::BasicBot::Slavorg - A IRC opbot

=head1 DESCRIPTION

slavorg was an opbot for #london.pm, writen by our very own davorg. And
lo, it was good. But in the nature of all good things, there were
problems. It was patched to understand voice as well as ops and it was
patched to do multi-channelness. But noone could figure out how the hell
to stop it opping just about everyone in the channel after every
netsplit. And this was annoying. And it would only op people when they
joined. And didn't deal with not having ops very well. And other, bad,
things.

I've re-written slavorg a few times now, and this latest version is the
nicest - based on L<Bot::BasicBot> so it doesn't have to manage all the
boring IRC stuff, and can focus on the opping and believing people.

=head1 SYNOPSIS

  use Bot::BasicBot::Slavorg;
  
  Bot::BasicBot::Slavorg->new(
    nick => "slavorg",
    server => "irc.perl.org",
    config_file => "slavorg.yaml",
    owner => "jerakeen",
  )->run;

=head1 IRC COMMANDS

Initially the bot won't join any channels, and will trust exactly one
person, the 'owner' defined in the new call. Open a query connection with
the bot, and tell it to join channels with the 'join' command. Once in a
channel, the bot can be told to trust people, believe people, etc.

=head2 trust nick1, nick2, nick3 [ in #channel | everywhere ]

Tells the bot to trust the given people, meaning that the bot will op
them if the bot is opped and they aren't. If there is a 'in #channel' at
the end, they will be trusted only in that channel. If there is an
'everywhere' at the end, they will be trusted 'globally' - these people
are effectively bot admins, as they will be able to tell the bot to join
and leave channels. If neither of these is passed, the people will be
trusted in the current channel.

This command must be given by someone with at least as much trust in the
place where trust will be given - a bot admin can tell the bot to trust
anyone, anywhere, someone trusted only in #foo can tell the bot to trust
people in #foo only, and someone not trusted can't tell the bot
anything.

=head2 believe nick1, nick2, nick3 [ in #channel | everywhere ]

belief works exactly as trust does, except that believed people will be
given voice in channel instead of ops. Trust is a superset of belief -
nicks that are trusted can't also be believed, there's no point, and you
can assign belief if you are trusted _or_ believed in the right context.

=head2 join #channel1, #channel2 and #channel3

Tells the bot to join the channels. The person giving this command must
be trusted 'everywhere'.

=head2 leave [#channel]

Tells the bot to leave the passed channel, or the current one if no channel
is passed. The person giving the command must be trusted in the channel to
be left.

=head1 SECURITY CONSIDERATIONS

There isn't any. Really. slavorg is a convenience bot for use on IRC networks
where you trust people and just don't want to lose ops. It is _trivial_ to
take over a channel that contains a slavorg. So don't run it on efnet, k?

In slightly more detail - slavorg tracks only the lower case version of
nicks, with trailing underscores removed for people with backup nicks who
don't want to have to trust them all. Changing your nick to that of a bot
admin with an underscore after it will let you take over the bot and
trust who you like. Have fun.

=head1 AUTHOR

Tom Insam <tom@jerakeen.org> based originally on slavorg by Dave Cross.

=cut

package Bot::BasicBot::Slavorg;
use warnings;
use strict;
use base qw( Bot::BasicBot );
use YAML qw (LoadFile DumpFile );

our $VERSION = "0.10";

sub init {
  my $self = shift;
  $self->load_settings();
  $self->trust("all", $self->owner, 1);
  
  return 1;
}

my $aliases = {
  do_trust => ["trust", "op"],
  do_believe => ["believe", "voice"],
  do_join => ["join"],
  do_part => ["part", "leave"],
};


my $commands;
for my $method (keys(%$aliases)) {
  for my $alias (@{ $aliases->{$method} }) {
    $commands->{$alias} = $method;
  }
}

sub help {
  my $self = shift;
  "I'm ".$self->nick.", an op-bot. Tell me to trust people and I'll op them. "
  ."Tell me to believe them, and I'll voice them. See http://search.cpan.org/perldoc?Bot::BasicBot::Slavorg for more details.";
}

sub said {
  my ($self, $mess) = @_;
  return unless $mess->{address};

  my ($command, $body) = split(/\s+/, $mess->{body}, 2);

  my $method = $commands->{$command};
  unless ($method) {
    return "I'm sorry?";
  }

  return $self->$method($mess, $body || "");
}

sub do_trust { shift->verb("trust", @_) }
sub do_believe { shift->verb("believe", @_) }

sub do_join {
  my ($self, $mess, $body) = @_;
  return "I don't trust you everywhere, $mess->{who}"
    unless $self->trust("all", $mess->{who});

  my @channels = split(/[\s,;]+/, $body);
  @channels = grep { !/^and$/i } @channels;

  $self->join($_) for @channels;
  return "Ok, joining @channels";
}

sub do_part {
  my ($self, $mess, $body) = @_;
  my $channel = $body || $mess->{channel};
  return "Leave where?" if (!$channel or $channel eq 'msg');

  return "I don't trust you in $channel, $mess->{who}"
    unless $self->trust($channel, $mess->{who});

  $self->part($channel);
  return "I'm leaving now";
}


sub chanjoin {
  my $self = shift;
  $self->save_settings;
  return undef;
}

sub chanpart {
  my $self = shift;
  $self->save_settings;
  return undef;
}

sub verb {
  my ($self, $verb, $mess, $body) = @_;

  my $in;
  if ($body =~ s/\s+in\s+(\#\S+)\s*$//i) { $in = $1 }
  my ($everywhere) = ($body =~ s/\s+(everywhere)\s*$//i);

  my $channel;
  $channel = $mess->{channel} unless $mess->{channel} eq 'msg';
  $channel = $in if $in;
  $channel = "all" if $everywhere;

  return "Sure, but where?" unless $channel;

  return "But I don't $verb _you_, $mess->{who}"
    unless $self->$verb($channel, $mess->{who});

  my @nicks = split(/[\s,;]+/, $body);
  @nicks = grep { !/^and$/i } @nicks;

  return "Trust _who_?" unless @nicks;

  my @already;
  my @verbed;

  for (@nicks) {
    if ($self->$verb($channel, $_)) {
      push @already, $_;
    } else {
      $self->trust($channel, $_, 0);
      $self->believe($channel, $_, 0);
      $self->$verb($channel, $_, 1);
      push @verbed, $_;
    }
  }

  if (@verbed > 1) { $verbed[-1] = "and $verbed[-1]" }
  if (@already > 1) { $already[-1] = "and $already[-1]" }

  my $return = "";
  if (@verbed)  { $return .= "I now $verb ".join(", ", @verbed)." in $channel. " }
  if (@already) { $return .= "I already $verb ".join(", ", @already).". " }
  return $return;
}


sub tick {
  my $self = shift;

  for my $channel ($self->channels) {

    # op the trusted non-ops
    for ($self->nonops_in($channel)) {
      $self->mode($channel, "+o", $_)
        if $self->trust( $channel, $_ );
    }

    # voice the believed non-voices
    for ($self->nonvoice_in($channel)) {
      $self->mode($channel, "+v", $_)
        if ($self->believe($channel, $_) and !$self->trust($channel, $_) );
    }

  }
  return 10;
}


sub trust { shift->relationship("trust", @_) }

sub believe {
  my $self = shift;
  my $channel = shift;
  my $nick = shift;
  if (@_) {
    return $self->relationship("believe", $channel, $nick, @_);
  }
  return $self->trust($channel, $nick)
    || $self->relationship("believe", $channel, $nick);
}

sub relationship {
  my $self = shift;
  my $type = shift;
  my $channel = shift;
  my $nick = shift;
  $nick = $self->canonical_nick($nick);
  if (@_) {
    $self->{data}{$type}{$channel}{$nick} = shift;
    $self->save_settings;
    return;
  }
  return $self->{data}{$type}{all}{$nick} || $self->{data}{$type}{$channel}{$nick};
}

sub canonical_nick {
  my ($self, $nick) = @_;
  $nick = lc($nick);
  $nick =~ s/_*$//;
  return $nick;
}

sub nonops_in {
  my ($self, $channel) = @_;
  my $data = $self->channel_data($channel) or return;
  return grep { ! $data->{$_}{op} } keys(%$data);
}

sub nonvoice_in {
  my ($self, $channel) = @_;
  my $data = $self->channel_data($channel) or return;
  return grep { ! $data->{$_}{op} && ! $data->{$_}{voice} } keys(%$data);
}

sub config_file {
  my ($self, $file) = @_;
  $self->{config_file} = $file if $file;
  return $self->{config_file} || "slavorg.yaml";
}

sub owner {
  my ($self, $owner) = @_;
  $self->{owner} = $owner if $owner;
  return $self->{owner} || "jerakeen";
}

sub load_settings {
  my $self = shift;
  
  $self->{data} = (-f "slavorg.yaml") ? eval { LoadFile( $self->config_file ) } : {};
  die "Error loading settings: $@\n" if $@;
  $self->channels( $self->{data}{channels} || [] );
}

sub save_settings {
  my $self = shift;
  $self->{data}{channels} = [ $self->channels ];
  DumpFile( $self->config_file, $self->{data} );
}

1;
