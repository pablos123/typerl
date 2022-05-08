package config;

use strict;
use warnings;

sub new {

    my $options = {};

    # Default values
    $options->{timer}          = 30;
    $options->{spaces}         = 2;
    $options->{show_cursor}    = 1;
    $options->{blank_lines}    = 2;
    $options->{word_quantity}  = 10;
    $options->{centered_words} = 1;
    $options->{start_of_line}  = 'fixed';
    $options->{error}          = 0;
    $options->{bad_defined}    = 0;

    if ( -f './config/config' ) {
        my $config_fh     = undef;
        my $config_string = '';

        open $config_fh, '<', './config/config';
        while ( my $line = <$config_fh> ) {
            $config_string .= $line;
        }
        close $config_fh;

        my @option_names = (
            'timer',         'spaces',
            'show_cursor',   'blank_lines',
            'word_quantity', 'centered_words',
            'start_of_line',
        );

        if ($config_string) {

            my $user_options = undef;
            eval "\$user_options = { $config_string }";

            if ($@) { $options->{error} = 1; }
            else {
                my $value;
                for my $option (@option_names) {
                    next if not defined $user_options->{$option};

                    $value = $user_options->{$option};

                    if ( $option eq 'timer' ) {
                        if ( $value <= 0 ) {
                            $options->{bad_defined} = $option;
                            next;
                        }
                        $options->{$option} = $value;
                    }
                    elsif ( $option eq 'spaces' ) {
                        if ( $value != 1 && $value != 2 ) {
                            $options->{bad_defined} = $option;
                            next;
                        }
                        $options->{$option} = $value;
                    }
                    elsif ( $option eq 'show_cursor' ) {
                        if ( $value != 0 && $value != 1 ) {
                            $options->{bad_defined} = $option;
                            next;
                        }
                        $options->{$option} = $value;
                    }
                    elsif ( $option eq 'blank_lines' ) {
                        if ( $value != 1 && $value != 2 && $value != 3 ) {
                            $options->{bad_defined} = $option;
                            next;
                        }
                        $options->{$option} = $value;
                    }
                    elsif ( $option eq 'word_quantity' ) {
                        if ( $value > 12 || $value < 1 ) {
                            $options->{bad_defined} = $option;
                            next;
                        }
                        $options->{$option} = $value;
                    }
                    elsif ( $option eq 'centered_words' ) {
                        if ( $value != 0 && $value != 1 ) {
                            $options->{bad_defined} = $option;
                            next;
                        }
                        $options->{$option} = $value;
                    }
                    elsif ( $option eq 'start_of_line' ) {
                        if ( $value ne 'centered' && $value ne 'fixed' ) {
                            $options->{bad_defined} = $option;
                            next;
                        }
                        $options->{$option} = $value;
                    }
                }
            }
        }
    }

    return bless $options;
}

1;
