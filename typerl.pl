use strict;
use warnings;

use Curses;
use Readonly;

use lib "./dict";
use lib "./config";

Readonly my $GOOD_CHAR_COLOR => 1;
Readonly my $BAD_CHAR_COLOR  => 2;

# Define the program title and the menu content
my $blank_sep = 2;
my $timer     = 30;
my $spaces    = 2;

main();

exit 0;

sub main {

    # Initialize curses
    initscr;
    if ( !has_colors ) {
        print("Your terminal does not support colors! :( \n");
        endwin;
        exit 1;
    }
    start_color;

    # Good character
    init_pair( $GOOD_CHAR_COLOR, COLOR_GREEN, COLOR_BLACK );

    # Bad character
    init_pair( $BAD_CHAR_COLOR, COLOR_RED, COLOR_BLACK );

    # Create a new window
    my $win = Curses->new;

    # Get the max x value and calculate the middle of the screen width
    my $max_x    = $win->getmaxx;
    my $middle_x = int( $max_x / 2 );

    # Create borders for the window
    box( $win, 0, 0 );

    # MENU INITILIZATION
    # ---------------------
    my $title        = "typerl";
    my @options      = ( "Play", "Settings", "Statistics", "Exit" );
    my @options_subs = ( \&play, \&settings, \&statistics );
    my $options_max  = $#options;

    # ---------------------

    my $y = $blank_sep;

    # Disable the cursor and the output of the pressed character
    # Make the title bold, print it and move the cursor down
    $win->attron( A_BOLD | noecho | curs_set(0) );
    addstring( $win, $y, $middle_x - int( ( length $title ) / 2 ), $title );
    $y += $blank_sep;
    $win->attroff(A_BOLD);

    # Highlight the first option, and move the cursor
    $win->attron(A_STANDOUT);
    addstring( $win, $y, $middle_x - int( ( length $options[0] ) / 2 ),
        $options[0] );
    $win->attroff(A_STANDOUT);
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

        $win->attron(A_STANDOUT);
        addstring( $win, $y,
            $middle_x - int( ( length $options[$option] ) / 2 ),
            $options[$option] );
        $win->attroff(A_STANDOUT);
    }

    $win = undef;
    endwin;
}

sub play {

    # Create a new window
    my $win = Curses->new;

    # Get the max x value and calculate the middle of the screen width
    my $max_x    = $win->getmaxx;
    my $middle_x = int( $max_x / 2 );

    # Create borders for the window
    box( $win, 0, 0 );

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

    # Generate words
    for my $i ( 1 .. 300 ) {
        my $new_word = $words[ int( rand( scalar @words ) ) ];
        if ( $i % 10 ) {
            $new_word .= ( ' ' x $spaces );
        }

        $line_len += int( ( length $new_word ) / 2 );
        $words_line .= $new_word;

        if ( !( $i % 10 ) ) {
            ## Add the new generated line to the window
            my $length = length $words_line;
            my $start  = $middle_x - int( $length / 2 );

            # Just add three lines
            if ( ( $i / 10 ) < 4 ) {
                addstring( $win, $row, $start, $words_line );
            }

            # Push the new line of words to the lines array
            # save the $length and the start column
            push @words_lines,
              { words => $words_line, start => $start, length => $length };

            # Move the cursor down
            $row += 2;

            # Reset counters
            $words_line = '';
            $line_len   = 0;
        }
    }

    # ---------------------
    # GAME LOOP
    # ---------------------
    # Prepare for the game loop
    my $line_count  = 0;
    my @line_chars  = split //, $words_lines[$line_count]->{words};
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
            until ( $timer_end || $words_count > 9 || $finished_line ) {
                my $input_char = getch($win);

                if ( $char_count < $line_length )
                {    # I am not in the end of the line
                    if ( $input_char eq ' ' ) {

                        # Advance all the current word characters
                        until (  $char_count >= $line_length
                              || $line_chars[$char_count] eq ' ' )
                        {
                            ++$char_count;
                        }

                        # Advance all the spaces
                        while ($char_count < $line_length
                            && $line_chars[$char_count] eq ' ' )
                        {
                            ++$char_count;
                        }

                        # If I am at the end of the line
                        if ( $char_count >= $line_length ) {
                            $finished_line = 1;
                        }

                        ++$words_count;
                    }
                    elsif ( $input_char eq $line_chars[$char_count] )
                    {    # Good character pressed
                        attron( $win, COLOR_PAIR($GOOD_CHAR_COLOR) );
                        addch(
                            $win, $row,
                            $start + $char_count,
                            $line_chars[$char_count]
                        );
                        attroff( $win, COLOR_PAIR($GOOD_CHAR_COLOR) );
                        ++$char_count;
                    }
                    else {    # Bad character pressed
                        attron( $win, COLOR_PAIR($BAD_CHAR_COLOR) );
                        addch(
                            $win, $row,
                            $start + $char_count,
                            $line_chars[$char_count]
                        );
                        attroff( $win, COLOR_PAIR($BAD_CHAR_COLOR) );
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

                # From now on im always in the middle row
                $row = 6;

                ++$line_count;
                @line_chars  = split //, $words_lines[$line_count]->{words};
                $start       = $words_lines[$line_count]->{start};
                $line_length = $words_lines[$line_count]->{length};

                # I am in the last line in sight, I need to show the next,
                # I don't want to move the y axis
                if ( $line_count > 1 ) {

                    # Clean the existing lines
                    addstring( $win, $row - 2, 4, ' ' x ( $max_x - 5 ) );
                    addstring( $win, $row,     4, ' ' x ( $max_x - 5 ) );
                    addstring( $win, $row + 2, 4, ' ' x ( $max_x - 5 ) );

                    addstring(
                        $win, $row - 2,
                        $words_lines[ $line_count - 1 ]->{start},
                        $words_lines[ $line_count - 1 ]->{words}
                    );

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

    return 0;
}

sub settings {
    return 0;
}

sub statistics {
    return 0;
}
