use strict;
use warnings;

use Curses;

use lib "./dict";

# Define the program title and the menu content
my $title = "typerl";
my @options = ("Play", "Settings", "Statistics", "Exit");
my $options_max = $#options;
my $blank_sep = 2;
my $timer = 3;

main();

exit 0;

sub main {
    # Initialize curses
    initscr;

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
                my @options_subs = (\&play, \&settings, \&statistics);
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
    my @english_words = @{$dict->{words}};

    # Preare for the word generator loop
    my $line = 4;
    my $line_word = '';
    my $line_len = 0;
    my @lines = ();
    # Generate words
    for my $i (1 .. 300) {
        my $new_word = "$english_words[int(rand(scalar @english_words))]  ";
        $line_len += int((length $new_word) / 2) + 2;
        $line_word .= $new_word;

        if(! ($i % 10)) {
            ## Add the new generated line to the window
            #addstring($win, $line, $middle_x - int((length $line_word) / 2) , $line_word);

            # Move the cursor down
            $line += 2;
            # Reset counters
            $line_word = '';
            $line_len = 0;
            # Add the new line of words to the lines array
            push @lines, $line_word;
        }
    }

    # Prepare for the timer's signal
    my $end = 0;
    local $SIG{HUP} = sub { $end = 1 };
    # Save the parent_pid for the child
    my $parent_pid = $$;

    # Creates the child for running the timer
    # the father is the main game, the child will signal
    # when time is up!
    my $pid = fork;
    die "Error forking timer" unless defined $pid;

    if($pid == 0) { # Child process, run the timer here
        # Sleep for the amount of seconds needed
        sleep $timer;
        # Signal the parent process
        kill HUP => $parent_pid;
        exit 0;
    } else { # Parent process, play here

        my $time = 0;
        until ($end) {
            refresh($win);
            addstring($win, 2, $middle_x, "$time");
            ++$time;
            sleep 1;
        }

        addstring($win, 10, 10, "Time's up!");
    }

    getch($win);

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
