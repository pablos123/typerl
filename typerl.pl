use strict;
use warnings;

use Curses;
use Readonly;

use lib "./dict";
use lib "./config";

Readonly my $NEUTRAL_CHAR => 0;
Readonly my $GOOD_CHAR    => 1;
Readonly my $BAD_CHAR     => 2;

# -------------------
# CONFIGURATION
# -------------------
require config;
my $config = config->new;

if ( $config->{error} ) {
    print "There are errors in the config file, using defaults...\n";
    <stdin>;
}
elsif ( $config->{bad_defined} ) {
    print
      "The value for '$config->{bad_defined}' option is not correct, ",
      "use the example to see the correct values.\n",
      "Using the default for that value... Press enter to play\n";
    <stdin>;
}

my $blank_sep     = $config->{blank_lines};
my $timer         = $config->{timer};
my $spaces        = $config->{spaces};
my $word_quantity = $config->{word_quantity};

# END CONFIGURATION
#-----------------------
main();

exit 0;

sub main {

    # Initialize curses
    initscr;
    if ( !has_colors ) {
        print("Your terminal does not support colors!\n");
        endwin;
        exit 1;
    }
    start_color;

    # Good character
    init_pair( $GOOD_CHAR, COLOR_GREEN, COLOR_BLACK );

    # Bad character
    init_pair( $BAD_CHAR, COLOR_RED, COLOR_BLACK );

    # Create a new window
    my $win = Curses->new;

    # Get the max x value and calculate the middle of the screen width
    my $max_x    = getmaxx($win);
    my $middle_x = int( $max_x / 2 );

    # Create borders for the window
    box( $win, 0, 0 );

    # MENU INITILIZATION
    # ---------------------
    # Define the program title and the menu content
    my $title        = "typerl";
    my @options      = ( "Play", "Statistics", "Exit" );
    my @options_subs = ( \&play, \&settings, \&statistics );
    my $options_max  = $#options;

    # ---------------------

    my $y = $blank_sep;

    # Disable the cursor and the output of the pressed character
    # Make the title bold, print it and move the cursor down
    attron( $win, A_BOLD | noecho | curs_set(0) );
    addstring( $win, $y, $middle_x - int( ( length $title ) / 2 ), $title );
    $y += $blank_sep;
    attroff( $win, A_BOLD );

    # Highlight the first option, and move the cursor
    attron( $win, A_STANDOUT );
    addstring( $win, $y, $middle_x - int( ( length $options[0] ) / 2 ),
        $options[0] );
    attroff( $win, A_STANDOUT );
    $y += $blank_sep;

    # Print the options along moving the cursor down
    for my $option_index ( 1 .. $#options ) {
        addstring( $win, $y,
            $middle_x - int( ( length $options[$option_index] ) / 2 ),
            $options[$option_index] );
        $y += $blank_sep;
    }

    # Prepare for the infinite loop
    my $move   = "";
    my $option = 0;
    $y = $blank_sep * 2;    # The y position of the first element

    while (1) {
        $move = getch($win);
        addstring( $win, $y,
            $middle_x - int( ( length $options[$option] ) / 2 ),
            $options[$option] );
        if ( $move eq "j" ) {
            if ( $option == $options_max ) {
                $y      = $blank_sep * 2;
                $option = 0;
            }
            else {
                $y += $blank_sep;
                $option++;
            }
        }
        elsif ( $move eq "k" ) {
            if ( $option == 0 ) {
                $y      = $options_max * $blank_sep + $blank_sep * 2;
                $option = $options_max;
            }
            else {
                $y -= $blank_sep;
                $option--;
            }
        }
        elsif ( $move eq "l" ) {

            # Exit option
            if ( $option == $options_max ) {
                last;
            }
            else {
                # Options to execute
                $options_subs[$option]->();
            }
        }

        attron( $win, A_STANDOUT );
        addstring( $win, $y,
            $middle_x - int( ( length $options[$option] ) / 2 ),
            $options[$option] );
        attroff( $win, A_STANDOUT );
    }

    $win = undef;
    endwin;
}

sub play {

    # Create a new window
    my $win = Curses->new;

    # Get the max x value and calculate the middle of the screen width
    my $max_x    = getmaxx($win);
    my $middle_x = int( $max_x / 2 );

    # Create borders for the window
    box( $win, 0, 0 );

    if ( $config->{show_cursor} ) {
        attron( $win, curs_set(1) );
    }

    # Prepare the dictionary
    require english;
    my $dict  = english->new;
    my @words = @{ $dict->{words} };

    # The y axis the cursor is in it, for printing the words in the correct
    # place
    my $row = 4;

    # ---------------------
    # PREPARE WORDS
    # ---------------------
    # Preare for the word generator loop
    # This list will contain all the words for this game and reapeated ones
    my @words_lines = ();
    my $words_line  = '';
    my $line_len    = 0;

    my $first_start = 0;

    # Generate words
    for my $i ( 1 .. 300 ) {
        my $new_word = $words[ int( rand( scalar @words ) ) ];
        if ( $i % $word_quantity ) {
            $new_word .= ( ' ' x $spaces );
        }

        $line_len += int( ( length $new_word ) / 2 );
        $words_line .= $new_word;

        if ( !( $i % $word_quantity ) ) {
            ## Add the new generated line to the window
            my $length = length $words_line;
            my $start  = 0;
            if ( $config->{start_line_fixed} ) {
                if ( ( $i / $word_quantity ) < 2 ) {
                    $first_start = $middle_x - int( $length / 2 );
                }
                $start = $first_start;
            }
            else {
                $start = $middle_x - int( $length / 2 );
            }

            # Just add three lines
            if ( ( $i / $word_quantity ) < 4 ) {
                addstring( $win, $row, $start, $words_line );

                # Move the cursor down
                $row += 2;
            }

            # Push the new line of words to the lines array
            # save the $length and the start column
            push @words_lines,
              { words => $words_line, start => $start, length => $length };

            # Reset counters
            $words_line = '';
            $line_len   = 0;
        }
    }

    # ---------------------
    # GAME LOOP
    # ---------------------
    # Prepare for the game loop
    my $line_count = 0;

    my $char_index = 0;
    my %line_chars =
      map { $char_index++ => { char => $_, state => $NEUTRAL_CHAR } } split //,
      $words_lines[$line_count]->{words};
    my %chars_count = ( bad => 0, good => 0 );

    my $start       = $words_lines[$line_count]->{start};
    my $line_length = $words_lines[$line_count]->{length};

    # Reset the cursor y position just for the first line
    $row = 4;

    # ------------------------------------------
    # TIMER

    # Prepare for the timer's signal
    my $timer_end = 0;
    local $SIG{HUP} = sub { $timer_end = 1 };

    # Save the parent_pid for the child
    my $parent_pid = $$;

    # Create the child for running the timer
    # the father is the main game, the child will signal
    # when time is up!
    my $pid = fork;
    if ( !defined $pid ) { die "Error forking timer"; }

    if ( $pid == 0 ) {    # Child process, run the timer here
                          # Sleep for the amount of seconds needed
        sleep $timer;

        # Signal the parent process
        kill HUP => $parent_pid;
        exit 0;
    }

    # TIMER FINISH
    # ------------------------------------------

    else {    # Parent process, play here

        until ($timer_end) {
            my $words_count   = 0;
            my $char_count    = 0;
            my $finished_line = 0;

            move( $win, $row, $start );

            until (  $timer_end
                  || $words_count > ( $word_quantity - 1 )
                  || $finished_line )
            {
                my $input_char = getch($win);

                if ( $char_count < $line_length )
                {    # I am not in the end of the line
                    if ( $input_char eq ' ' ) {

                        # Advance all the current word characters
                        attron( $win, COLOR_PAIR($BAD_CHAR) );
                        until (  $char_count >= $line_length
                              || $line_chars{$char_count}->{char} eq ' ' )
                        {
                            addch(
                                $win, $row,
                                $start + $char_count,
                                $line_chars{$char_count}->{char}
                            );
                            $line_chars{$char_count}->{state} = $BAD_CHAR;
                            ++$char_count;
                        }
                        attroff( $win, COLOR_PAIR($BAD_CHAR) );

                        # Advance all the spaces
                        while ($char_count < $line_length
                            && $line_chars{$char_count}->{char} eq ' ' )
                        {
                            ++$char_count;
                        }

                        # If I am at the end of the line
                        if ( $char_count >= $line_length ) {
                            $finished_line = 1;
                        }

                        move( $win, $row, $start + $char_count );

                        ++$words_count;
                    }
                    elsif ( $input_char eq $line_chars{$char_count}->{char} )

                    {    # Good character pressed
                        attron( $win, COLOR_PAIR($GOOD_CHAR) );
                        addch(
                            $win, $row,
                            $start + $char_count,
                            $line_chars{$char_count}->{char}
                        );
                        attroff( $win, COLOR_PAIR($GOOD_CHAR) );
                        $line_chars{$char_count}->{state} = $GOOD_CHAR;
                        ++$char_count;
                    }
                    else {    # Bad character pressed
                        attron( $win, COLOR_PAIR($BAD_CHAR) );
                        addch(
                            $win, $row,
                            $start + $char_count,
                            $line_chars{$char_count}->{char}
                        );
                        attroff( $win, COLOR_PAIR($BAD_CHAR) );
                        $line_chars{$char_count}->{state} = $BAD_CHAR;
                        ++$char_count;
                    }
                }
                else {    # I am in the end of the line

             # Print the wrong characters pressed until the space bar is pressed
                    until ( $input_char eq ' ' ) {
                        attron( $win, COLOR_PAIR(2) );
                        addch( $win, $row, $start + $char_count, $input_char );
                        attroff( $win, COLOR_PAIR(2) );
                        ++$char_count;

                        # Get next character
                        $input_char = getch($win);
                    }
                    $finished_line = 1;
                    ++$words_count;
                }
            }

            # If not ending because the timer
            if ( !$timer_end ) {

                # Clean the bad trailing characters for the first line
                if ( $line_count == 0 ) {
                    for (
                        my $i = $start + $line_length ;
                        $i < $max_x - 4 ;
                        ++$i
                      )
                    {
                        addch( $win, $row, $i, ' ' );
                    }
                }

                # From now on im always in the middle row
                $row = 6;

                ++$line_count;
                my %previous_line_chars = %line_chars;

                # Generate the next line
                $char_index = 0;
                %line_chars =
                  map {
                    $char_index++ => { char => $_, state => $NEUTRAL_CHAR }
                  }
                  split //,
                  $words_lines[$line_count]->{words};
                $start       = $words_lines[$line_count]->{start};
                $line_length = $words_lines[$line_count]->{length};

                # I am in the last line in sight, I need to show the next,
                # I don't want to move the y axis
                if ( $line_count > 1 ) {

                    # Clean the existing lines
                    addstring( $win, $row - 2, 4, ' ' x ( $max_x - 5 ) );
                    addstring( $win, $row,     4, ' ' x ( $max_x - 5 ) );
                    addstring( $win, $row + 2, 4, ' ' x ( $max_x - 5 ) );

                    # Persist the state of the previous line
                    for (
                        my $i = 0 ;
                        $i < $words_lines[ $line_count - 1 ]->{length} ;
                        ++$i
                      )
                    {
                        if ( $previous_line_chars{$i}->{state} == $GOOD_CHAR ) {
                            attron( $win, COLOR_PAIR($GOOD_CHAR) );
                        }
                        elsif ( $previous_line_chars{$i}->{state} == $BAD_CHAR )
                        {
                            attron( $win, COLOR_PAIR($BAD_CHAR) );
                        }
                        addch(
                            $win, $row - 2,
                            $words_lines[ $line_count - 1 ]->{start} + $i,
                            $previous_line_chars{$i}->{char}
                        );

                        attroff( $win,
                            COLOR_PAIR($GOOD_CHAR) | COLOR_PAIR($BAD_CHAR) );

                    }

                    addstring( $win, $row, $start,
                        $words_lines[$line_count]->{words} );

                    addstring(
                        $win, $row + 2,
                        $words_lines[ $line_count + 1 ]->{start},
                        $words_lines[ $line_count + 1 ]->{words}
                    );
                }
            }
        }

        getch($win);
    }

    attroff( $win, curs_set(0) );

    return 0;
}

sub settings {
    return 0;
}

sub statistics {
    return 0;
}
