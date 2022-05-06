use strict;
use warnings;

use Curses;

use lib "./dict";

# Define the program title and the menu content
my $title = "typerl";
my @options = ("Play", "Settings", "Statistics", "Exit");
my @options_subs = (\&play, \&settings, \&statistics);
my $options_max = $#options;
my $blank_sep = 2;
my $timer = 15;
my $spaces = 2;

main();

exit 0;

sub main {
    # Initialize curses
    initscr;
    if(! has_colors) {
        print("Your terminal does not support colors! :( \n");
        endwin;
        exit 1;
    }
    start_color;

    # Good character
    init_pair(1, COLOR_GREEN, COLOR_BLACK);
    # Bad character
    init_pair(2, COLOR_RED, COLOR_BLACK);

    # Create a new window
    my $win = Curses->new;
    
    # Get the max x value and calculate the middle of the screen width
    my $max_x = $win->getmaxx;
    my $middle_x = int($max_x / 2);

    # Create borders for the window
    box($win, 0, 0);

    my $y = $blank_sep;

    # Disable the cursor and the output of the pressed character
    # Make the title bold, print it and move the cursor down
    $win->attron(A_BOLD | noecho | curs_set(0));
    addstring($win, $y, $middle_x - int((length $title) / 2), $title);
    $y += $blank_sep;
    $win->attroff(A_BOLD);

    # Highlight the first option, and move the cursor
    $win->attron(A_STANDOUT);
    addstring($win, $y, $middle_x - int((length $options[0]) / 2), $options[0]);
    $win->attroff(A_STANDOUT);
    $y += $blank_sep;

    # Print the options along moving the cursor down
    for my $option_index (1 .. $#options) {
        addstring($win, $y, $middle_x - int((length $options[$option_index]) / 2), $options[$option_index]);
        $y += $blank_sep;
    }

    # Prepare for the infinite loop
    my $move = "";
    my $option = 0;
    $y = $blank_sep * 2; # The y position of the first element

    while(1) { 
        $move = getch($win);
        addstring($win, $y, $middle_x - int((length $options[$option]) / 2), $options[$option]);
        if($move eq "j") {
            if($option == $options_max) {
                $y = $blank_sep * 2;
                $option = 0;
            } else {
                $y += $blank_sep;
                $option++;
            }
        } elsif($move eq "k") {
            if($option == 0) {
                $y = $options_max * $blank_sep + $blank_sep * 2;
                $option = $options_max;
            } else {
                $y -= $blank_sep;
                $option--;
            }
        } elsif ($move eq "l") {
            if($option == $options_max) {
                last;
            } else {
                # Options to execute
                $options_subs[$option]->();
            }
        }

        $win->attron(A_STANDOUT);
        addstring($win, $y, $middle_x - int((length $options[$option]) / 2), $options[$option]);
        $win->attroff(A_STANDOUT);
    }

    $win = undef;
    endwin;
}


sub play {

    # Create a new window
    my $win = Curses->new;

    # Get the max x value and calculate the middle of the screen width
    my $max_x = $win->getmaxx;
    my $middle_x = int($max_x / 2);

    # Create borders for the window
    box($win, 0, 0);

    # Prepare the dictionary
    require english;
    my $dict = english->new;
    my @words = @{$dict->{words}};

    # Preare for the word generator loop
    my $row = 4;
    my $words_line = '';
    my $line_len = 0;
    my @words_lines = ();
    # Generate words
    for my $i (1 .. 300) {
        my $new_word = '';
        if(! ($i % 10)) {
            $new_word = $words[int(rand(scalar @words))];
        } else {
            $new_word = $words[int(rand(scalar @words))] . ' ' x $spaces;
        }

        $line_len += int((length $new_word) / 2);
        $words_line .= $new_word;

        if(! ($i % 10)) {
            ## Add the new generated line to the window
            my $length = length $words_line;
            my $start = $middle_x - int($length / 2);
            if (($i / 10) < 4) {
                addstring($win, $row, $start, $words_line);
            }

            # Push the new line of words to the lines array and concat to
            # the long string
            push @words_lines, { words => $words_line, start => $start, length => $length };

            # Move the cursor down
            $row += 2;
            # Reset counters
            $words_line = '';
            $line_len = 0;
        }
    }

    # Prepare for the timer's signal
    my $end = 0;
    local $SIG{HUP} = sub { $end = 1 };
    # Save the parent_pid for the child
    my $parent_pid = $$;

    # Create the child for running the timer
    # the father is the main game, the child will signal
    # when time is up!
    my $pid = fork;
    if(! defined $pid) { die "Error forking timer"; }

    if($pid == 0) { # Child process, run the timer here
        # Sleep for the amount of seconds needed
        sleep $timer;
        # Signal the parent process
        kill HUP => $parent_pid;
        exit 0;
    } else { # Parent process, play here

        my $line_count = 0;
        my @chars = split //, $words_lines[$line_count]->{words};
        my $start = $words_lines[$line_count]->{start};
        my $line_length = $words_lines[$line_count]->{length};
        my $row = 4;
        until ($end) {
            my $words_count = 0;
            my $char_count = 0;
            until($end || $words_count > 9 || $char_count >= $line_length) {
                my $input_char = getch($win);
                if ($input_char eq ' ') {
                    ++$words_count;
                    $char_count += $spaces;
                } elsif ($input_char eq $chars[$char_count]) {
                    attron($win, COLOR_PAIR(1));
                    addch($win, $row, $start + $char_count, $chars[$char_count]);
                    attroff($win, COLOR_PAIR(1));
                    ++$char_count;
                } else {
                    attron($win, COLOR_PAIR(2));
                    addch($win, $row, $start + $char_count, $chars[$char_count]);
                    attroff($win, COLOR_PAIR(2));
                    ++$char_count;
                }

            }
            ++$line_count;
            $row += 2;
            # If not ending because the timer
            if(! $end ) {
                @chars = split //, $words_lines[$line_count]->{words};
                $start = $words_lines[$line_count]->{start};
            }
            # We are in the last line in sight, we need to show the next 
            #if($line_count > 1) {
            #    addstring($win, 2, $middle_x, $char);
            #}
            #refresh($win);
        }
    }


    return 0;
}

sub settings {
    # Create a new window
    my $win = Curses->new;

    # Get the max x value and calculate the middle of the screen width
    my $max_x = $win->getmaxx;
    my $middle_x = int($max_x / 2);

    # Create borders for the window
    box($win, 0, 0);

    return 0;
}

sub statistics {
    return 0;
}
