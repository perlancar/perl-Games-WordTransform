package Games::WordTransform;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use experimental 'smartmatch';

use List::Util qw(shuffle);

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(create_word_transform);

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Word transform game',
};

$SPEC{create_word_transform} = {
    v => 1.1,
    summary => 'Create a letter-by-letter transformation from one word '.
        'to another',
    description => <<'_',

This function allows you to create a letter-by-letter transformation from one
word to another, where each step of the transformation is also a word, formed by
changing one word of the previous step. Example (from WORDS to PARTY):

    WORDS
    WARDS
    CARDS
    CARTS
    PARTS
    PARTY

_
    args => {
        # XXX also allow to specify a wordlist module
        words => {
            summary => 'List of words to choose from',
            schema  => ['array*' => of => 'str*'],
            req => 1,
        },
        word1 => {
            summary => 'Specify first word',
            description => <<'_',

If not specified, a random word will be chosen.

_
            schema => 'str*',
        },
        num_steps => {
            summary => 'Number of steps to produce',
            schema => 'int*',
            req => 1,
        },
        # XXX option to create N transformations instead of just 1, because each
        # transformation involves an overhead of creating a wordlist hash and
        # letter-frequency analysis
    },
};
sub create_word_transform {
    my (%args) = @_;

    my $words     = $args{words}
        or return [400, "Please specify 'words'"];
    my $num_steps = $args{num_steps}
        or return [400, "Please specify 'num_steps'"];

    # create hash form for fast lookup
    my %words = map {$_=>1} @$words;

    # analyze letter frequency
    my %freqs; # key=letter, val=num of occurences
    for my $w (@$words) {
        $freqs{$_}++ for split //, $w;
    }
    # sorted by frequency, from most common
    my @letters = sort {$freqs{$b}<=>$freqs{$a}} keys %freqs;

    # algorithm is currently brute-force, we replace letter by letter and hope
    # to find another valid word. repeat until number of steps reached.

    my $word1    = $args{word1} // $words->[rand @$words];
    # allow some retries if we happens to pick a word that's hard to transform
    my $retries1 = defined($args{word1}) ? 1 : 10;

    my $tries1 = 0;
    my @res;
  TRY1:
    while (1) {
        #say "D:starting from an empty list";
        @res = ();
        my $word = $word1;
        $tries1++;
      TRY2:
        while (@res <= $num_steps) {
            #say "D:transforming word '$word'";
            # pick the letter to replace randomly
            my @orders = shuffle(0..length($word)-1);
          TRY3:
            while (@orders) {
                my $pos = shift @orders;
                # XXX use a slightly different order of letters, to be less
                # predictable
                for my $letter (@letters) {
                    my $try_word = $word;
                    substr($try_word, $pos, 1) = $letter;
                    next if $try_word eq $word;
                    if ($words{$try_word} &&
                            $try_word ne $word1 &&
                                !($try_word ~~ @res)) {
                        #say "D:found word '$try_word'";
                        push @res, $try_word;
                        $word = $try_word;
                        next TRY2;
                    }
                }
            }
            # can't find transform from last word, backtrack
            if (@res) {
                # try another step
                $word = pop @res;
                #say "D:fail to find a transform, retrying from word '$word'";
                next TRY2;
            } elsif (++$tries1 < $retries1) {
                # start over with a new first word
                $word1 = $words->[rand @$words];
                #say "D:fail to find a transform, retrying from another first word '$word'";
                next TRY1;
            } else {
                return [412, "Can't find more transform ".
                            "(last try was: $word1 -> $word)"];
            }
        }
        # requested number of steps have been reached
        return [200, "OK", [$word1, @res]];
    }
}

sub new {
    require Module::List;
    require Module::Load;

    my $class = shift;
    my %attrs = @_;

    # select and load default wordlist
    my $mods = Module::List::list_modules(
        "Games::Word::Wordlist::", {list_modules=>1});
    my @wls = map {s/.+:://; $_} keys %$mods;
    print "Available wordlists: ", join(", ", @wls), "\n";
    my $wl = $attrs{word_list};
    if (!$wl) {
        if (($ENV{LANG} // "") =~ /^id/ && "KBBI" ~~ @wls) {
            $wl = "KBBI";
        } else {
            if (@wls > 1) {
                @wls = grep {$_ ne 'KBBI'} @wls;
            }
            $wl = $wls[rand @wls];
        }
    }
    die "Can't find module for wordlist '$wl'" unless $wl ~~ @wls;
    my $mod = "Games::Word::Wordlist::$wl";
    Module::Load::load($mod);
    print "Loaded wordlist from $mod\n";

    # select eligible words from the wordlist
    my @words;
    {
        my $wlobj = $mod->new;
        my $l1 = int($attrs{min_len} // 5);
        my $l2 = int($attrs{max_len} // $l1 // 5);
        @words = $wlobj->words_like(qr/\A[a-z]{$l1,$l2}\z/);
        die "Can't find any eligible words in wordlist '$wl'"
            unless @words;
        $attrs{_wlobj} = $wlobj;
        $attrs{words} = \@words;
    }

    $attrs{num_words} //= 10;
    $attrs{min_steps} //= 3;
    $attrs{max_steps} //= 8;

    bless \%attrs, $class;
}

sub run {
    my $self = shift;
}

1;
# ABSTRACT:

=for Pod::Coverage ^(.+)$

=head1 SYNOPSIS

Play game:

 % wordtransform

Use the transform functionality:

 use Games::WordTransform qw(create_word_transform);
 my $res = create_word_transform(words => [...], steps => 3);


=head1 DESCRIPTION

=head1 SEE ALSO
