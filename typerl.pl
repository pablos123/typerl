use strict;
use warnings;

use utf8;

use Curses;
use Readonly;

use lib "./dict";
use lib "./config";

Readonly my $NEUTRAL_CHAR => 0;
Readonly my $GOOD_CHAR    => 1;
Readonly my $BAD_CHAR     => 2;
Readonly my $MAX_WORDS    => 300;

# -------------------
# CONFIGURATION
# -------------------
require config;
Readonly my $config => config->new;

if ( $config->{error} ) {
    print
"There are errors in the config file, using defaults... Press enter to play\n";
    <stdin>;
}
elsif ( $config->{bad_defined} ) {
    print
      "The value for '$config->{bad_defined}' option is not correct, ",
      "use the example to see the correct values.\n",
      "Using the default for that value... Press enter to play\n";
    <stdin>;
}

Readonly my $timer            => $config->{timer};
Readonly my $spaces           => $config->{spaces};
Readonly my $show_cursor      => $config->{show_cursor};
Readonly my $line_breaks      => $config->{line_breaks};
Readonly my $menu_line_breaks => $config->{menu_line_breaks};
Readonly my $word_quantity    => $config->{word_quantity};
Readonly my $centered_words   => $config->{centered_words};
Readonly my $fixed_line_start => $config->{fixed_line_start};

Readonly my $MAX_LINES => int( $MAX_WORDS / $word_quantity );

# END CONFIGURATION
#-----------------------
typerl();

exit 0;

sub typerl {

    # Initialize curses
    initscr;
    if ( !has_colors ) {
        endwin;
        print("Your terminal does not support colors!\n");
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

    # MENU INITILIZATION
    # ---------------------
    # Define the program title and the menu content
    my $title        = "typerl";
    my @options      = ( "Play", "Statistics", "Exit" );
    my @options_subs = ( \&play, \&settings, \&statistics );
    my $options_max  = $#options;

    # Terminal size errors
    for my $option ( $title, @options ) {

        # Error due to the terminal being too small
        # Substract four for the box to render properly and for error margin
        if ( length $option > ( $max_x - 4 ) ) {
            endwin;
            print
"The terminal is too small!\n The menu cannot be generated properly... You can:\n",
              "- Make the terminal bigger\n",
              "- Make the words in the menu smaller\n";
            exit 1;
        }
    }

    # Check if the three lines of words will fit in the terminal window
    my $menu_last_row = ( scalar @options + 1 ) * $menu_line_breaks;
    if ( $menu_last_row > ( getmaxy($win) - 4 ) ) {
        endwin;
        print
"The terminal is too small!\n The menu cannot be generated properly... You can:\n",
          "- Make the terminal bigger\n";
        exit 1;
    }

    # ---------------------

    # Create borders for the window
    box( $win, 0, 0 );

    # Enable function keys
    keypad( $win, 1 );

    # ---------------------

    my $y = $menu_line_breaks;

    # Disable the cursor and the output of the pressed character
    # Make the title bold, print it and move the cursor down
    attron( $win, A_BOLD | noecho | curs_set(0) );
    addstring( $win, $y, $middle_x - int( ( length $title ) / 2 ), $title );
    $y += $menu_line_breaks;
    attroff( $win, A_BOLD );

    # Highlight the first option, and move the cursor
    attron( $win, A_STANDOUT );
    addstring( $win, $y, $middle_x - int( ( length $options[0] ) / 2 ),
        $options[0] );
    attroff( $win, A_STANDOUT );
    $y += $menu_line_breaks;

    # Print the options along moving the cursor down
    for my $option_index ( 1 .. $#options ) {
        addstring( $win, $y,
            $middle_x - int( ( length $options[$option_index] ) / 2 ),
            $options[$option_index] );
        $y += $menu_line_breaks;
    }

    # Prepare for the infinite loop
    my $move   = "";
    my $key    = 0;
    my $option = 0;
    $y = $menu_line_breaks * 2;    # The y position of the first element

    while (1) {
        ( $move, $key ) = getchar($win);
        addstring( $win, $y,
            $middle_x - int( ( length $options[$option] ) / 2 ),
            $options[$option] );

        if ( defined $key ) {
            if ( $key == KEY_DOWN ) {
                $move = 'j';
            }
            elsif ( $key == KEY_UP ) {
                $move = 'k';
            }
            elsif ( $key == KEY_RIGHT ) {
                $move = 'l';
            }
            else {
                $move = '';
            }
        }
        if ( $move eq 'j' ) {
            if ( $option == $options_max ) {
                $y      = $menu_line_breaks * 2;
                $option = 0;
            }
            else {
                $y += $menu_line_breaks;
                $option++;
            }
        }
        elsif ( $move eq 'k' ) {
            if ( $option == 0 ) {
                $y = $options_max * $menu_line_breaks + $menu_line_breaks * 2;
                $option = $options_max;
            }
            else {
                $y -= $menu_line_breaks;
                $option--;
            }
        }
        elsif ( $move eq 'l' ) {

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

    # The cursor y axis value, for printing the words in the correct
    # place
    my $first_row = 0;
    if ($centered_words) {

        # Place the lines in the middle of the screen
        my $middle_y = int( getmaxy($win) / 2 );
        $first_row = $middle_y - $line_breaks;
    }
    else {

        # Just put the lines on top of the screen
        $first_row = $line_breaks * 2;
    }

    # Check if the three lines of words will fit in the terminal window
    my $last_row = $first_row + ( 2 * $line_breaks );
    if ( $last_row > ( getmaxy($win) - 4 ) ) {
        endwin;
        print
"The terminal is too small!\n The words cannot be generated properly... You can:\n",
          "- Make the terminal bigger\n";
        exit 1;
    }

    # Get the max x value and calculate the middle of the screen width
    my $max_x    = getmaxx($win);
    my $middle_x = int( $max_x / 2 );

    # Create borders for the window
    box( $win, 0, 0 );

    if ($show_cursor) {
        attron( $win, curs_set(1) );
    }

    # Enable function keys
    keypad( $win, 1 );

    # ---------------------
    # PREPARE WORDS
    # ---------------------
    #
    # Prepare the dictionary
    require spanish;
    my $dict  = spanish->new;
    my @words = @{ $dict->{words} };

    # Preare for the word generator loop
    # This list will contain all the words for this game and reapeated ones
    my @words_lines = ();
    my $words_line  = '';
    my $line_len    = 0;

    # For fixed line starts
    my $first_start = 0;

    # Generate words
    for my $i ( 1 .. $MAX_WORDS ) {
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

            # Start lines always in the same column
            if ($fixed_line_start) {

                # If this is the first line, calculate the start for all
                # the other lines
                if ( ( $i / $word_quantity ) < 2 ) {
                    $first_start = $middle_x - int( $length / 2 );
                }

                # Always make the start of the line like the start of
                # the first line
                $start = $first_start;
            }

            # Start the lines always in the middle of the screen
            else {
                $start = $middle_x - int( $length / 2 );
            }

            # Error due to the terminal being too small
            # Substract four for the box to render properly and for error margin
            if ( $length > ( $max_x - 4 ) ) {
                endwin;
                print
"The terminal is too small!\n The words cannot be generated properly... You can:\n",
                  "- Make the terminal bigger\n",
"- Make the program to generate less words per line with the config parameter 'word_quantity'\n",
                  "- Make the words in the dictionary smaller\n";
                exit 1;
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

    # Reset the row to the first row
    my $row = $first_row;

    # Draw three lines to begin the game.
    for my $start_line ( 0 .. 2 ) {
        addstring(
            $win,
            $row + ( $start_line * $line_breaks ),
            $words_lines[$start_line]->{start},
            $words_lines[$start_line]->{words}
        );
    }

    # Prepare for the game loop
    my $line_count = 0;

    my $char_index = 0;
    my %line_chars =
      map { $char_index++ => { char => $_, state => $NEUTRAL_CHAR } } split //,
      $words_lines[$line_count]->{words};
    my %chars_count = ( bad => 0, good => 0 );

    my $start       = $words_lines[$line_count]->{start};
    my $line_length = $words_lines[$line_count]->{length};

    # To wait if all words are completed
    my $wait = 0;

    # Counters for the game statistics

    my $statistics = {
        total_chars_typed => 0,
        good_chars        => 0,
        bad_chars         => 0,
    };

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
    if ( !defined $pid ) {
        endwin;
        print "Error forking timer\n";
        exit 1;
    }

    if ( $pid == 0 ) {    # Child process, run the timer here
                          # Sleep for the amount of seconds needed
        sleep $timer;

        # Signal the parent process
        kill HUP => $parent_pid;
        exit 0;
    }

    # END TIMER
    # ------------------------------------------

    else {    # Parent process, play here

        until ($timer_end) {

            # If I finished all the words, wait for the timer to end
            # Almost impossible unless you spam the space bar
            if ($wait) {

                # Make getchar equals to ERR if there is no character to be
                # readed (Clean stdin while I'm waiting)
                nodelay( $win, 1 );
                while ( !$timer_end ) {
                    getchar($win);

                    # Don't kill the cpu
                    sleep(0.3);
                }
                nodelay( $win, 0 );
                last;
            }

            my $words_count   = 0;
            my $char_count    = 0;
            my $finished_line = 0;
            my $line_again    = 0;
            my ( $input_char, $key );

            move( $win, $row, $start );

            until (  $timer_end
                  || $words_count > ( $word_quantity - 1 )
                  || $finished_line )
            {
                if ( !$line_again ) {
                    ( $input_char, $key ) = getchar($win);
                }
                else {
                    $line_again = 0;
                }

                # Function keys handler
                if ( defined $key ) {

                    # Eraser implementation
                    if ( $key == KEY_BACKSPACE ) {
                        if ($char_count) {
                            --$char_count;
                            attroff( $win,
                                COLOR_PAIR($GOOD_CHAR) |
                                  COLOR_PAIR($BAD_CHAR) );

                            addstring(
                                $win, $row,
                                $start + $char_count,
                                $line_chars{$char_count}->{char}
                            );
                            move( $win, $row, $start + $char_count );
                        }
                        next;
                    }
                }

                if ( $char_count < $line_length )
                {    # I am not in the end of the line
                    if ( defined $input_char && $input_char eq ' ' ) {

                        # Advance all the current word characters
                        attron( $win, COLOR_PAIR($BAD_CHAR) );
                        until (  $char_count >= $line_length
                              || $line_chars{$char_count}->{char} eq ' ' )
                        {
                            addstring(
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
                    elsif ( defined $input_char
                        && $input_char eq $line_chars{$char_count}->{char} )

                    {    # Good character pressed
                        attron( $win, COLOR_PAIR($GOOD_CHAR) );
                        addstring(
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
                        addstring(
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
             # or until I delete characters to the end of the line

                    until (  $char_count < $line_length
                          || defined $input_char && $input_char eq ' '
                          || $line_again )
                    {
                        # Function keys handler
                        if ( defined $key ) {

                            # Eraser implementation
                            if ( $key == KEY_BACKSPACE ) {
                                if ( $char_count > $line_length ) {
                                    --$char_count;
                                    attroff( $win,
                                        COLOR_PAIR($GOOD_CHAR) |
                                          COLOR_PAIR($BAD_CHAR) );

                                    addstring( $win, $row, $start + $char_count,
                                        ' ' );
                                    move( $win, $row, $start + $char_count );
                                }
                                else {
                                    $line_again = 1;
                                }
                            }
                            if ( !$line_again ) {
                                ( $input_char, $key ) = getchar($win);
                            }
                        }
                        else {

                            # I'm not close to the border of the window
                            if ( $start + $char_count < ( $max_x - 4 ) ) {
                                attron( $win, COLOR_PAIR(2) );
                                addstring( $win, $row, $start + $char_count,
                                    $input_char );
                                attroff( $win, COLOR_PAIR(2) );
                                ++$char_count;

                            }

                            # Get next character
                            ( $input_char, $key ) = getchar($win);
                        }
                    }

                    # Finished because all the characters are writen
                    # And I'm not in the line again
                    if ( $char_count >= $line_length && !$line_again ) {
                        $finished_line = 1;
                        ++$words_count;
                    }
                }
            }

            if ( $line_count >= ( $MAX_LINES - 1 ) ) {
                $wait = 1;
            }

            # If not ending because the timer and not have to wait
            if ( !$timer_end && !$wait ) {

                # Clean the bad trailing characters for the first line
                if ( $line_count == 0 ) {
                    for (
                        my $i = $start + $line_length ;
                        $i < $max_x - 4 ;
                        ++$i
                      )
                    {
                        addstring( $win, $row, $i, ' ' );
                    }
                }

                # From now on im always in the middle row
                $row = $first_row + $line_breaks;

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
                    addstring( $win, $row - $line_breaks,
                        4, ' ' x ( $max_x - 5 ) );
                    addstring( $win, $row, 4, ' ' x ( $max_x - 5 ) );
                    addstring( $win, $row + $line_breaks,
                        4, ' ' x ( $max_x - 5 ) );

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
                        addstring(
                            $win,
                            $row - $line_breaks,
                            $words_lines[ $line_count - 1 ]->{start} + $i,
                            $previous_line_chars{$i}->{char}
                        );

                        attroff( $win,
                            COLOR_PAIR($GOOD_CHAR) | COLOR_PAIR($BAD_CHAR) );

                    }

                    addstring( $win, $row, $start,
                        $words_lines[$line_count]->{words} );

                    # I don't want to draw the next line if I'm in the last line
                    if ( $line_count < ( $MAX_LINES - 1 ) ) {
                        addstring(
                            $win,
                            $row + $line_breaks,
                            $words_lines[ $line_count + 1 ]->{start},
                            $words_lines[ $line_count + 1 ]->{words}
                        );
                    }
                }
            }
        }

        getchar($win);
    }

    attroff( $win, curs_set(0) );

    return 0;
}

sub statistics {
    return 0;
}
