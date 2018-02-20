#!/usr/bin/perl

use strict;
use warnings;

use Lingua::Stem qw/stem/;

my %docs;
my @uncat;

my $minimum_category_size = 6;

open my $handle, '<dedup_questions' or die $!;
chomp(my @lines = <$handle>); close $handle;

my %stopwords;
open $handle, '<stopwords' or die $!;
foreach my $word (<$handle>) {
  chomp $word;
  $stopwords{$word} = 1;
}
close $handle;

my @doc_rules = (
  { regex => qr/(?:james bond| 007)/i, category => 'JAMES BOND' },
  { regex => qr/^(?:in (?:the year )?)?194\d /i, category => "THE 1940'S" },
  { regex => qr/^(?:in (?:the year )?)?195\d /i, category => "THE 1950'S" },
  { regex => qr/^(?:in (?:the year )?)?196\d /i, category => "THE 1960'S" },
  { regex => qr/^(?:in (?:the year )?)?197\d /i, category => "THE 1970'S" },
  { regex => qr/^(?:in (?:the year )?)?198\d /i, category => "THE 1980'S" },
  { regex => qr/^(?:in (?:the year )?)?199\d /i, category => "THE 1990'S" },
  { regex => qr/^(?:in (?:the year )?)?20\d\d /i, category => "THE 2000'S" },
  { regex => qr/(?:Name The Year|In what year)/, category => 'NAME THE YEAR' },
  { regex => qr/baby names/i, category => 'BABY NAMES' },
  { regex => qr/what word mean/i, category => 'Definitions' },
  { regex => qr/What (?:one word|word links)/i, category => 'GUESS THE WORD' },
  { regex => qr/^(If [Yy]ou [Ww]ere [Bb]orn|Astrology)/i, category => 'Astrology' },
  { regex => qr/[Oo]lympics/, category => 'Olympics' },
  { regex => qr/^How many/i, category => 'HOW MANY' },
  { regex => qr/(?:^What is a group|Group Nouns)/, category => 'animal groups' },
  { regex => qr/(?:[Ww]hat is the fear|phobia is (?:a|the) fear|Phobias)/, category => 'Phobias' },
  { regex => qr/who won the oscar/i, category => 'Oscars' },
  { regex => qr/(?:area code|country code)/, category => 'Phone COUNTRY Codes' },
  { regex => qr/17th.century/i, category => "17TH CENTURY" },
  { regex => qr/18th.century/i, category => "18TH CENTURY" },
  { regex => qr/19th.century/i, category => "19TH CENTURY" },
  { regex => qr/shakespear/i, category => "SHAKESPEARE" },
  { regex => qr/world.cup/i, category => "WORLD CUP" },
  { regex => qr/computer science/i, category => "COMPUTER SCIENCE" },
  { regex => qr/computer/i, category => "COMPUTERS" },
  { regex => qr/science fict/i, category => "SCI-FI" },
  { regex => qr/science/i, category => "SCIENCE" },
  { regex => qr/technolog/i, category => "TECHNOLOGY" },
  { regex => qr/^games /i, category => "GAMES" },
  { regex => qr/x.?men/i, category => "X-MEN" },
  { regex => qr/beatles/i, category => "BEATLES" },
  { regex => qr/^chiefly british/i, category => "BRITISH SLANG" },
  { regex => qr/^SLANG /i, category => "SLANG" },
  { regex => qr/^US SLANG$/i, category => "SLANG" },
  { regex => qr/\bchess\b/i, category => "CHESS" },
  { regex => qr/sherlock holmes/i, category => "SHERLOCK HOLMES" },
  { regex => qr/stephen king/i, category => "STEPHEN KING" },
  { regex => qr/wizard of oz/i, category => "WIZARD OF OZ" },
  { regex => qr/philosoph/i, category => "PHILOSOPHY" },
  { regex => qr/.*: '.*\.'/, category => "GUESS THE WORD" },
  { regex => qr/monty python/i, category => "MONTY PYTHON" },
  { regex => qr/musical/i, category => "MUSICALS" },
  { regex => qr/^the name/, category => "NAME THAT THING" },
  { regex => qr/hit single/, category => "HIT SINGLES" },
  { regex => qr/^a group of/, category => "A GROUP OF IS CALLED" },
  { regex => qr/^music/, category => "MUSIC" },
);

my @rename_rules = (
  { old => qr/^007$/,  new => "JAMES BOND" },
  { old => qr/^191\d/, new => "THE 1910'S" },
  { old => qr/^192\d/, new => "THE 1920'S" },
  { old => qr/^193\d/, new => "THE 1930'S" },
  { old => qr/^194\d/, new => "THE 1940'S" },
  { old => qr/^195\d/, new => "THE 1950'S" },
  { old => qr/^196\d/, new => "THE 1960'S" },
  { old => qr/^197\d/, new => "THE 1970'S" },
  { old => qr/^198\d/, new => "THE 1980'S" },
  { old => qr/^199\d/, new => "THE 1990'S" },
  { old => qr/^200\d/, new => "THE 2000'S" },
  { old => qr/19TH CENT ART/, new => "19TH CENTURY" },
  { old => qr/^20'S$/, new => "THE 1920'S" },
  { old => qr/^30'S$/, new => "THE 1930'S" },
  { old => qr/^40'S$/, new => "THE 1940'S" },
  { old => qr/^50'S$/, new => "THE 1950'S" },
  { old => qr/^60'S$/, new => "THE 1960'S" },
  { old => qr/^70'S$/, new => "THE 1970'S" },
  { old => qr/^80'S$/, new => "THE 1980'S" },
  { old => qr/^THE 50'S$/, new => "THE 1950'S" },
  { old => qr/^THE 60'S$/, new => "THE 1960'S" },
  { old => qr/^THE 70'S$/, new => "THE 1970'S" },
  { old => qr/^THE 80'S$/, new => "THE 1980'S" },
  { old => qr/^80'S TRIVIA$/, new => "THE 1980'S" },
  { old => qr/^90'S$/, new => "THE 1990'S" },
  { old => qr/(?:MOVIES|FILM) \/ TV/, new => "TV / MOVIES"},
  { old => qr/TV-MOVIES/, new => "TV / MOVIES"},
  { old => qr/MOVIE TRIVIA/, new => "MOVIES" },
  { old => qr/AT THE MOVIES/, new => "MOVIES" },
  { old => qr/^\d+ MOVIES/, new => "MOVIES" },
  { old => qr/^1993 THE YEAR/, new => "THE 1990'S" },
  { old => qr/TV \/ MOVIE/, new => "TV / MOVIES" },
  { old => qr/^TV (?:SITCOM|TRIVIA|SHOWS|HOSTS)/, new => "TV" },
  { old => qr/^TV:/, new => "TV" },
  { old => qr/TVS STTNG/, new => "STAR TREK" },
  { old => qr/ACRONYM/, new => "ACRONYM SOUP" },
  { old => qr/ANIMAL TRIVIA/, new => "ANIMAL KINGDOM" },
  { old => qr/^ANIA?MALS$/, new => "ANIMAL KINGDOM" },
  { old => qr/^ADS$/, new => "ADVERTISING" },
  { old => qr/^AD JINGLES$/, new => "ADVERTISING" },
  { old => qr/^AD SLOGANS$/, new => "ADVERTISING" },
  { old => qr/SLOGAN/, new => "ADVERTISING" },
  { old => qr/^TELEVISION$/, new => "TV" },
  { old => qr/^QUICK QUICK$/, new => "QUICK! QUICK!" },
  { old => qr/^QUOTES$/, new => "QUOTATIONS" },
  { old => qr/^SHAKESPEAREAN CHARACTER$/, new => "SHAKESPEARE" },
  { old => qr/^USELESS INFO$/, new => "USELESS FACTS" },
  { old => qr/^WORLD CUP 2002$/, new => "WORLD CUP" },
  { old => qr/^AUTHOR$/, new => "AUTHORS" },
  { old => qr/^ART$/, new => "ARTS" },
  { old => qr/^BOOZE/, new => "BOOZE" },
  { old => qr/CHIEFLY BRITISH/, new => "BRITISH SLANG" },
  { old => qr/^SCIFI/, new => "SCI-FI" },
  { old => qr/^HITCHHIKER/, new => "HITCHHIKER'S GUIDE" },
  { old => qr/^SCIENCE FANTASY/, new => "SCI-FI" },
  { old => qr/^ANATOMY$/, new => "ANATOMY & MEDICAL" },
  { old => qr/^SECRETIONS$/, new => "ANATOMY & MEDICAL" },
  { old => qr/^PHYSIOLOGY$/, new => "ANATOMY & MEDICAL" },
  { old => qr/^THE BODY$/, new => "ANATOMY & MEDICAL" },
  { old => qr/^BEATLES FIRST WORDS$/, new => "BEATLES" },
  { old => qr/^MUSIC LEGENDS$/, new => "MUSIC ARTISTS" },
  { old => qr/^TOYS GAMES$/, new => "TOYS & GAMES" },
  { old => qr/^PEANUTS COMICS$/, new => "COMICS" },
  { old => qr/^COMPUTER GAMES$/, new => "VIDEO GAMES" },
  { old => qr/^ABBR$/, new => "ABBREVIATIONS" },
  { old => qr/^BABY NAMES BEG/, new => "BABY NAMES" },
  { old => qr/^CURRENCY & FLAGS$/, new => "CURRENCIES & FLAGS" },
  { old => qr/^CURRENCIES$/, new => "CURRENCIES & FLAGS" },
  { old => qr/^FUN$/, new => "FUN & GAMES" }, 
  { old => qr/^GAMES$/, new => "FUN & GAMES" }, 
  { old => qr/^HOBBIES & LEISURE$/, new => "FUN & GAMES" },
  { old => qr/^MISC GAMES$/, new => "FUN & GAMES" },
  { old => qr/^SIMPSONS$/, new => "THE SIMPSONS" },
  { old => qr/^SMURFS$/, new => "THE SMURFS" },
  { old => qr/^MLB$/, new => "BASEBALL" },
  { old => qr/ENTERTAINMENT/, new => "ENTERTAINMENT" },
  { old => qr/CONFUSCIOUS SAY/, new => "CONFUCIUS SAY" },
  { old => qr/NOVELTY SONGS/, new => "NOVELTY SONGS" },
  { old => qr/NAME THE MOVIE WITH THE SONG/, new => "NAME THE MOVIE FROM THE SONG" },
  { old => qr/SCI.?FI AUTHORS/, new => "SCI-FI" },
  { old => qr/SCI.?FI/, new => "SCI-FI" },
  { old => qr/ON THIS DAY IN JANUARY/, new => "ON THIS DAY IN JANUARY" },
  { old => qr/MYTHOLOGY/, new => "MYTHOLOGY" },
  { old => qr/X-MEN/, new => "X-MEN" },
  { old => qr/US CAPITIALS/, new => "US CAPITALS" },
  { old => qr/^SCI$/, new => "SCI-FI" },
  { old => qr/SCIENCE.?FICTION/, new => "SCI-FI" },
  { old => qr/WHO RULED ROME/, new => "ROMAN RULERS" },
  { old => qr/^WHO DIRECTED/, new => "NAME THE DIRECTOR" },
  { old => qr/PHILOSOPHER/, new => "PHILOSOPHY" },
  { old => qr/^SIMILI?ES?/, new => "SIMILES" },
  { old => qr/^SCIENCE /, new => "SCIENCE" },
  { old => qr/^ROMEO & JULIET/, new => "SHAKESPEARE" },
  { old => qr/^SAYINGS & SMILES$/, new => "SAYINGS & SIMILES" },
  { old => qr/^SAYING$/, new => "SAYINGS & SIMILES" },
  { old => qr/^EPL$/, new => "SOCCER" },
  { old => qr/^NZ$/, new => "NEW ZEALAND" },
  { old => qr/^NZ /, new => "NEW ZEALAND" },
  { old => qr/[NB]URSERY RHYME/, new => "FAIRYTALES & NURSERY RHYMES" }, 
  { old => qr/NURESRY RHYME/, new => "FAIRYTALES & NURSERY RHYMES" }, 
  { old => qr/^GEOGRAPH/, new => "GEOGRAPHY" },
  { old => qr/TREKKIE/, new => "STAR TREK" },
  { old => qr/^STAR TREK/, new => "STAR TREK" },
  { old => qr/^SPORT(?!S)/, new => "SPORTS" },
  { old => qr/WORDS CONTAINING/, new => "GUESS THE WORD" },
  { old => qr/MONTY PYTHON/, new => "MONTY PYTHON" },
  { old => qr/BARBIE/, new => "BARBIE DOLL" },
  { old => qr/(?:AMERICAN|INTL) BEER/, new => "BEER" },
);

my @skip_rules = (
  qr/true or false/i,
);

my @not_a_category = (
  qr/CHIEFLY BRITISH/,
  qr/^SLANG \w+/,
  qr/^IN 1987 18/,
  qr/^WHO CO$/,
);

my %refilter_rules = (
  "SPORTS" => [
    { regex => qr/baseball/i, category => "BASEBALL" },
    { regex => qr/world series/i, category => "BASEBALL" },
    { regex => qr/super.?bowl/i, category => "FOOTBALL" },
    { regex => qr/N\.?B\.?A\.?/i, category => "BASKETBALL" },
    { regex => qr/N\.?F\.?L\.?/i, category => "FOOTBALL" },
    { regex => qr/N\.?H\.?L\.?/i, category => "HOCKEY" },
    { regex => qr/basketball/i, category => "BASKETBALL" },
    { regex => qr/cricket/i, category => "CRICKET" },
    { regex => qr/golf/i, category => "GOLF" },
    { regex => qr/hockey/i, category => "HOCKEY" },
    { regex => qr/association football/, category => "SOCCER" },
    { regex => qr/soccer/, category => "SOCCER" },
    { regex => qr/football/i, category => "FOOTBALL" },
    { regex => qr/bowling/i, category => "BOWLING" },
    { regex => qr/olympics/i, category => "OLYMPICS" },
    { regex => qr/tennis/i, category => "TENNIS" },
    { regex => qr/box(?:ing|er)/i, category => "BOXING" },
    { regex => qr/swim/i, category => "SWIMMING" },
    { regex => qr/wimbledon/i, category => "TENNIS" },
    { regex => qr/rugby/i, category => "RUGBY" },
  ],
  "ART & LITERATURE" => [
    { regex => qr/Lotr:/, category => "LORD OF THE RINGS" },
    { regex => qr/shakespear/i, category => "SHAKESPEARE" },
    { regex => qr/sherlock holmes/i, category => "SHERLOCK HOLMES" },
    { regex => qr/stephen king/i, category => "STEPHEN KING" },
  ],
  "CARTOON TRIVIA" => [
    { regex => qr/disney/i, category => "DISNEY" },
    { regex => qr/x-men/i, category => "X-MEN" },
    { regex => qr/dc comics/i, category => "DC COMICS" },
  ],
);

print STDERR "Categorizing documents\n";

for my $i (0 .. $#lines) {
  # Remove/fix stupid things
  $lines[$i] =~ s/\s*category:\s*//gi;
  $lines[$i] =~ s/(\w:)(\w)/$1 $2/g;
  $lines[$i] =~ s{/}{ / }g;
  $lines[$i] =~ s{&}{ & }g;
  $lines[$i] =~ s/\s+/ /g;
  $lines[$i] =~ s/^Useless Trivia: What word means/Definitions: What word means/i;
  $lines[$i] =~ s/^useless triv \d+/Useless Trivia/i;
  $lines[$i] =~ s/^general\s*(?:knowledge)?\s*\p{PosixPunct}\s*//i;
  $lines[$i] =~ s/^(?:\(|\[)(.*?)(?:\)|\])\s*/$1: /;
  $lines[$i] =~ s/star\s?wars/Star Wars/ig;
  $lines[$i] =~ s/^sport\s*[:-]\s*(.*?)\s*[:-]/$1: /i;
  $lines[$i] =~ s/^trivia\s*[:;-]\s*//i;
  $lines[$i] =~ s/^triv\s*[:;-]\s*//i;

  my @l = split /`/, $lines[$i];

  my $skip = 0;
  foreach my $rule (@skip_rules) {
    if ($l[0] =~ m/$rule/) {
      print STDERR "Skipping doc $i (matches $rule): $l[0] ($l[1])\n";
      $skip = 1;
      last;
    }
  }
  next if $skip;

  # If the question has an obvious category, use that
  if ($l[0] =~ m/^(.{3,30}?)\s*[:;-]/ or $l[0] =~ m/^(.{3,30}?)\s*\./) {
    my $cat = uc $1;
    my $max_spaces = 5;
    $max_spaces = 3 if $cat =~ s/\.$//;
    my $nspc = () = $cat =~ m/\s+/g;
    if ($nspc <= $max_spaces) {
      if ($cat !~ m/(general|^A |_+| u$| "c$)/i) {
        my $pass = 1;
        foreach my $regex (@not_a_category) {
          if ($cat =~ m/$regex/) {
            $pass = 0;
            last;
          }
        }

        if ($pass) {
          $cat =~ s/^\s+|\s+$//g;
          $cat = uc $cat;
          $cat =~ s/'//g;
          $cat =~ s/\.//g;
          $cat =~ s/(?:\s+$|\R|^"|"$|^-|^\[|\]$)//g;
          $cat =~ s/\s+/ /g;
          $cat =~ s/(\d+)S/$1'S/g;
          $cat =~ s/ (?:AND|N|'N) / & /;

          foreach my $rule (@rename_rules) {
            if ($cat =~ m/$rule->{old}/) {
              $cat = uc $rule->{new};
              last;
            }
          }

          print STDERR "Using obvious $cat for doc $i: $l[0] ($l[1])\n";
          push @{$docs{$cat}}, $i;
          next;
        }
      }
    }
  }

  my $found = 0;
  foreach my $rule (@doc_rules) {
    if ($l[0] =~ m/$rule->{regex}/) {
      my $cat = uc $rule->{'category'};
      push @{$docs{$cat}}, $i;
      $found = 1;
      print STDERR "Using rules $cat for doc $i: $l[0] ($l[1])\n";
      last;
    }
  }

  next if $found;

  print STDERR "Uncategorized doc $i: $l[0] ($l[1])\n";

  push @uncat, $i;
}

foreach my $key (keys %refilter_rules) {
  for (my $i = 0; $i < @{$docs{$key}}; $i++) {
    my $doc = $docs{$key}->[$i];
    my @l = split /`/, $lines[$doc];
    foreach my $rule (@{$refilter_rules{$key}}) {
      if ($l[0] =~ m/$rule->{regex}/) {
        print STDERR "Refiltering doc $doc from $key to $rule->{category} $l[0] ($l[1])\n";
        push @{$docs{$rule->{category}}}, $doc;
        splice @{$docs{$key}}, $i--, 1;
      }
    }
  }
}

print STDERR "Done phase 1\n";
print STDERR "Generated ", scalar keys %docs, " categories.\n";

my $small = 0;
my $total = 0;
my @approved;

foreach my $cat (sort { @{$docs{$b}} <=> @{$docs{$a}} } keys %docs) {
  print STDERR "  $cat: ", scalar @{$docs{$cat}}, "\n";

  if (@{$docs{$cat}} < $minimum_category_size) {
    $small++ 
  } else {
    $total += @{$docs{$cat}};
    push @approved, $cat;
  }
}

print STDERR "-" x 80, "\n";
print STDERR "Small categories: $small; total cats: ", (scalar keys %docs) - $small, " with $total questions.\n";
print STDERR "-" x 80, "\n";

foreach my $cat (sort keys %docs) {
  print STDERR "  $cat: ", scalar @{$docs{$cat}}, "\n" if @{$docs{$cat}} < $minimum_category_size;
}

print STDERR "Uncategorized: ", scalar @uncat, "\n";

my @remaining_uncat;
my $i = 0;
$total = @uncat;
foreach my $doc (sort { $lines[$a] cmp $lines[$b] } @uncat) {
  print STDERR "$i / $total\n" if $i % 1000 == 0;
  $i++;
  my @l = split /`/, $lines[$doc];
  my @doc_words = split / /, $l[0];
  @doc_words = map { local $_ = $_; s/\p{PosixPunct}//g; lc $_ } @doc_words;
  @doc_words = @{ stem grep { length $_ and not exists $stopwords{$_} } @doc_words};

  #print STDERR "doc words for $doc: $l[0]: @doc_words\n";

  my $categorized = 0;
  foreach my $cat (sort { length $b <=> length $a } @approved) {
    next if $cat =~ m/ANIMAL IN YOU/;
    next if $cat =~ m/BOXING/;

    my @cat_words = split / /, $cat;
    @cat_words = map { local $_ = $_; s/\p{PosixPunct}//g; lc $_ } @cat_words;
    @cat_words = @{ stem grep { length $_ and not exists $stopwords{$_} } @cat_words};

    my %matches;
    foreach my $cat_word (@cat_words) {
      foreach my $doc_word (@doc_words) {
        if ($cat_word eq $doc_word) {
          $matches{$cat_word} = 1;
          goto MATCH if keys %matches == @cat_words;
        }
      }
    }

    MATCH:
    if (keys %matches == @cat_words) {
      print STDERR "Adding doc $doc to $cat: $l[0] ($l[1])\n";
      push @{$docs{$cat}}, $doc;
      $categorized = 1;
      last;
    }
  }

  if (not $categorized) {
    push @remaining_uncat, $doc;
  }
}

$total = 0;

foreach my $cat (@approved) {
  $total += @{$docs{$cat}};
}

print STDERR "-" x 80, "\n";
print STDERR "Categories: ", scalar @approved, " with $total questions.\n";
print STDERR "-" x 80, "\n";

foreach my $cat (sort @approved) {
  print STDERR "$cat ... ";

  my $count = 0;
  foreach my $i (@{$docs{$cat}}) {
    print "$cat`$lines[$i]\n";
    $count++;
  }

  print STDERR "$count questions.\n";
}

print STDERR "-" x 80, "\n";

print STDERR "Remaining uncategorized: ", scalar @remaining_uncat, "\n";

foreach my $i (sort { $lines[$a] cmp $lines[$b] } @remaining_uncat) {
  print STDERR "uncategorized: $lines[$i]\n";
}