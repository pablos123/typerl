use strict;
use warnings;

use Curses;

# Define the program title and the menu content
my $title = "typerl";
my @options = ("Play", "Practice", "Statistics", "Exit");
my $options_max = $#options;
my $blank_sep = 2;

main();

exit 0;

sub main {
    # Initialize curses
    initscr;

    # Create a new window
    my $win = Curses->new();
    
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
                execute_option($option);
            }
        }

        $win->attron(A_STANDOUT);
        addstring($win, $y, $middle_x - int((length $options[$option]) / 2), $options[$option]);
        $win->attroff(A_STANDOUT);
    }

    $win = undef;
    endwin;
}


sub execute_option {
    my $option = shift;
}
