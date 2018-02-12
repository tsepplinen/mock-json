#! /usr/bin/perl

use JSON;
use English;

use strict;

my $HELP = << "HELP_END";
Example use:
    perl mock-json.pl --template="template.json" --out="mock.json" --amount=20

Flags:
    --help, -h, /h, /help
        Display this help text.
    --template=<filename>
        Template file to determine what to output.
        Format of the template is shown in the file example-template.json.
    --amount
        Amount of objects to generate.
    --out=<filename>
        File to write into, if not provided, prints to stdout.
    --pretty
        Pretty prints the outputted json.
    --overwrite
        Overwrites the output file if it exists.
    
HELP_END

sub RandomInt {
    my $params = scalar(@ARG);
    my $start;
    my $end;

    if ($params == 0) {
        $start = 0;
        $end = 1;
    }
    elsif ($params == 1) {
        $start = 0;
        $end = $ARG[0] || $start + 1;
    } elsif ($params == 2) {
        $start = $ARG[0] || 0;
        $end = $ARG[1] || $start + 1;
    } else {
        $start = $ARG[0] || 0;
        $end = $ARG[-1] || $start + 1;
    }

    my $range =  $end - $start + 1;
    return $start + int rand($range);
}

sub RandomDecimal {
    my $params = scalar(@ARG);
    my $start;
    my $end;

    if ($params == 0) {
        $start = 0;
        $end = 1;
    }
    elsif ($params == 1) {
        $start = 0;
        $end = $ARG[0] || $start + 1;
    } elsif ($params == 2) {
        $start = $ARG[0] || 0;
        $end = $ARG[1] || $start + 1;
    } else {
        $start = $ARG[0] || 0;
        $end = $ARG[-1] || $start + 1;
    }

    my $range =  $end - $start;

    return $start + rand($range);
}

sub RandomListItem {
    my @list = @ARG;
    my ($random, $max);
    $max = (@list -1);
    $random = RandomInt($max);
    my $item = $list[$random];
    return $item;
}

sub MakeIncrement {

    my $counter = $ARG[0] || 1;

    my $increment = $ARG[1] || 1;

    my $inner = sub {
        my $value = $counter;
        $counter += $increment;
        return $value;
    };

    return $inner;
}

sub MakeIntRandomizer {
    my $start = $ARG[0];
    my $end = $ARG[1];
    my $randomizer = sub {
        return RandomInt($start, $end);
    };

    return $randomizer;
}

sub MakeDecimalRandomizer {
    my ($start, $end) = @ARG;
    my $precision = $ARG[2] || 2;
    my $randomizer = sub {
        my $val = RandomDecimal($start, $end);
        $val = sprintf("%." . $precision . "f", $val);
        $val = $val + 0; # Convert string to number
        return $val;
    };
    return $randomizer;
}

sub FileToList ($) {
    my $filename = $ARG[0];
    
    open(my $fh, '<:encoding(UTF-8)', $filename)
        or die "Could not open file '$filename'";

    my @list;
    my $counter = 1;
    while(<$fh>) {
        $counter += 1;
        s/^\s+//;
        s/\s+$//;
        push @list, $ARG;
    }

    return @list;
}

sub MakeTextRandomizer ($$$) {
    my ($filename, $repeat, $separator) = @ARG;
    $separator = $separator || " ";
    my @textList = FileToList($filename);
    my $randomizer = sub {
        my $string = RandomListItem(@textList);
        for (2..$repeat) {
            $string = $string . $separator . RandomListItem(@textList);
        }
        return $string;
    };
    return $randomizer;
}

sub CreateInstructions ($) {

    my %instructions;
    my $filename = $ARG[0];
    my $template_json;

    # Slurp the template file
    open(my $fh, '<:encoding(UTF-8)', $filename) or die "Could not open template file '$filename'"; #$!";
    {
        local $/ = undef;
        $template_json = <$fh>;
    }
    close $fh;
    
    my %template_hash = %{ decode_json $template_json };  

    for my $key (keys %template_hash) {
        my %field_hash = %{ $template_hash{$key} };
        my $type = $field_hash{type} || "unknown";
        if ($type eq "integer") {
            if ($field_hash{method} eq "increment") {
                my $start = $field_hash{start};
                my $increment = $field_hash{increment};
                $instructions{$key} = MakeIncrement($start, $increment);
            } elsif ($field_hash{method} eq "random") {
                my $start = $field_hash{start};
                 my $end = $field_hash{end};
                $instructions{$key} = MakeIntRandomizer($start, $end);
            }
        } elsif ($type eq "decimal") {
            
            if ($field_hash{method} eq "random") {
                my $start = $field_hash{start};
                my $end = $field_hash{end};
                my $precision =$field_hash{precision};
                $instructions{$key} = MakeDecimalRandomizer($start, $end, $precision);
            }
        } elsif ($type eq "text") {
            if ($field_hash{method} eq "random") {
                my $filename = $field_hash{file};
                my $repeat = $field_hash{repeat} || 1;
                my $separator = $field_hash{separator} || " ";

                $instructions{$key} = MakeTextRandomizer($filename, $repeat, $separator);
            }
        }
    }

    return %instructions;
}


# Gathers command line arguments starting with -- into a hash
sub GetOptionsFromArgs {

    my %hash;
    for my $arg (@ARGV) {
        if ($arg =~ /^--(.+)=(.+)$/) {
            $hash{$1} = $2;
        } elsif ($arg =~ /^--(.+)$/) {
            $hash{$1} = 1;
        } elsif ($arg =~ /^(--help|-h|\/h|\/help)$/) {
            $hash{help} = 1;
        }
    }

    return %hash;
}

sub FileExists($) {
    my $file = $ARG[0];
    return -f $file;
}

sub GenerateObjects($%) {
    my ($amount, %instructions_hash) = @ARG;
    my @out_json_array;

    for (1..$amount) {
        my %hash;
        for my $key (sort keys %instructions_hash) {
            $hash{$key} = $instructions_hash{$key}->();
        }
        push @out_json_array, \%hash;
    }
    return @out_json_array;
}

sub Main {
    # Json parser object
    my $json = JSON->new->utf8->canonical->space_before(0);

    # Command line parameters
    my %options = GetOptionsFromArgs();

    # Instruction set used to output data
    my %instructions_hash;

    # Output object
    my @out_json_array;

    # Amount of objects to generate, defaults to 10.
    my $amount = $options{amount} || 10;

    # File to output to
    my $outputFile = $options{out};

    if ($options{help} || !@ARGV) {
        print $HELP;
        return;
    }
    
    if (FileExists($outputFile)) {
        unless ($options{overwrite}) {
            print "File \"$outputFile\" already exists, use --overwrite flag to write to existing file.";
            return;
        }
    } 

    # If --pretty, config json to use pretty
    if ($options{pretty}) {
        $json = $json->pretty;
    }

    # Use seed if provided
    if ($options{seed}) {
        srand(int $options{seed});
    }

    # Read the template file
    if ($options{template}) {
        %instructions_hash = CreateInstructions($options{template});
    } else {
        print "Aborting, no template file provided!";
        return;
    }

    @out_json_array = GenerateObjects($amount, %instructions_hash);
    
    my $result_json = $json->encode(\@out_json_array);

    if ($outputFile) {
        # Output json to file
        open(my $fh, '>:encoding(UTF-8)', $outputFile) or die "Could not open file '$outputFile'";
        print $fh $result_json;
        print "\nGenerated $amount objects to $outputFile\n";
    } else {
        print $result_json; 
    }
}

Main();

# End of file