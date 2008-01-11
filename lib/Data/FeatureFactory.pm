package Data::FeatureFactory;

=head1 NAME

Data::FeatureFactory - evaluate features normally or numerically

=head1 SYNOPSIS

 # in the module that defines features
 package MyFeatures;
 use base qw(Data::FeatureFactory);
 
 our @features = (
    { name => 'no_of_letters', type => 'int', range => '0 .. 5' },
    { name => 'first_letter',  type => 'cat', 'values' => ['a' .. 'z'] },
 );
 
 sub no_of_letters {
    my ($word) = @_;
    return length $word
 }
 
 sub first_letter {
    my ($word) = @_;
    return substr $word, 0, 1
 }

 # in the main script
 package main;
 use MyFeatures;
 my $f = MyFeatures->new;
 
 # evaluate all the features on all your data and format them numerically
 for my $record (@data) {
     my @values = $f->evaluate('ALL', 'numeric', $record);
     print join(' ', @values);
 }
 
 # specify the features to evaluate and gather the result in binary form
 my @vector = $f->evaluate([qw(no_of_letters first_letter)], 'binary', 'foo');

=head1 DESCRIPTION

Data::FeatureFactory automates evaluation of features of data samples and optionally
encodes them as numbers or as binary vectors.

=head2 Defining features

The features are defined as subroutines in a package inheriting from Data::FeatureFactory.
A subroutine is declared to be a feature by being mentioned in the package array
C<@features>. Options for the features are also specified in this array. Its
minimum structure is as follows:

 @features = (
    { name => "name of feature 1" },
    { name => "name of feature 2" },
    ...
 )

The elements of the array must be hashrefs and each of them must have a C<name>
field. Other fields can specify options for the features. These are:

=over 4

=item type

Specifies if the feature is C<categorial>, C<numeric>, C<integer> or
C<boolean>.  Only the first three characters, case insensitive, are considered,
so you can as well say C<cat>, C<Num>, C<integral> or C<Boo!>. The default type
is categorial.

Integer and numeric features will have values forced to numbers. Boolean ones
will have values converted to 1/0 depending on Perl's notion of True/False. If
you use warnings, you'll get one if your numeric feature returns a non-numeric
string.

=item values

Lists the acceptable values for the feature to return. If a different value is
returned by the subroutine, the whole feature vector is discarded.
Alternatively, a default value can be specified. Whenever the order of the
values matters, it is honored (as in transfer to numeric format). The values can
be specified as an arrayref (in which case the order is regarded) or as a
hashref, in which case the values are pseudo-randomly ordered, but the loading
time is faster and transfer to numeric or binary format is faster as well. If
the values are specified as a hashref, then keys of the hash shall contain the
values of the feature and values of the hash should be 1's.

=item default

Specifies a default value to be substituted when the feature returns something
not listed in C<values>.

=item values_file

The values can either be listed directly or in a file. This option specifies
its name. This option must not appear in combination with the C<values> option.
Each value shall be on one line, with no headers, no intervening whitespace no
comments and no empty lines.

=item range

In case of integer and numeric features, an allowed range can be specified
instead of the values. This option cannot appear together with the C<values> or
C<values_file> option. The behavior is the same as with the C<values> option.
The interval specified is closed, so returning the limit value is OK. The range
shall be specified by two numeric expressions separated by two or more dots with
optional surrounding whitespace - for example 2..5 or -0.5 ...... +1.000_005.
The stuff around the dots are not checked to be valid numeric expressions. But
you should get a warning if you use them when you supply something nonsensical.

You can also specify a range for numeric (non-integer) features. The return
value will be checked against it but unlike integer features, this will not
generate a list of acceptible values. Therefore, range is not enough to specify
for a numeric feature if you want to have it converted to binary. (though
converting floating-point values to binary vectors seems rather quirky by
itself)

=item postproc

This option defines a subroutine that is to be used as a filter for the
feature's return value. It comes in handy when you, for example, have a feature
returning UTF-8 encoded text and you need it to appear ASCII-encoded but you
need to specify the acceptable values in UTF-8. As this use-case suggests, the
postprocessing takes place after the value is checked against the list of
acceptable values. The value for this option shall either be a coderef or the
name of the preprocessing function. If the function is not available in the
current namespace, Data::FeatureFactory will attempt to find it.

The postprocessing only takes place when the feature is evaluated normally -
that is, when its output is not being transformed to numeric or binary format.

=item code

Normally, the features are defined as subroutines in the package that inherits
from Data::FeatureFactory. However, the definition can also be provided as a coderef
in this option or in the C<%features> hash of the package. The priority is: 1)
the C<code> option, 2) the C<%features> hash, and 3) the package subroutine.

=item format

Features can be output in different ways - see below. The format in which the
features are evaluated is normally specified for all features in the call to
C<evaluate>. You can override it for specific features with this option.

You'll mostly use this to prevent the target (to-predict) feature from being
numified or binarified: { name => 'target', format => 'normal' }.

=back

Note that both the feature and the optional postprocessing routine are evaluated
in scalar context.

=head2 Creating the features object

Data::FeatureFactory has two methods: C<new> and C<evaluate>. C<new> creates an
object that can then be used to evaluate features. Please do *not* override the
C<new> method. If you do, then be sure that it calls
C<Data::FeatureFactory::new> properly. This method accepts an optional
argument - a hashref with options. Currently, only the 'N/A' option is
supported. See below for details.

=head2 Evaluating features

The C<evaluate> method of Data::FeatureFactory takes these
arguments: 1) names of the features to evaluate, 2) the format in which they
should be output and 3) arguments for the features themselves.

The first argument can be an arrayref with the names of the features, or it can
be the "ALL" string, which denotes that all features defined shall be evaluated.
If it contains any other string, then it's interpreted as the name of the only
feature to evaluate.

The second argument is C<normal>, C<numeric> or C<binary>. C<normal> means that
the features' return values should be left alone (but postprocessed if such
option is set). C<numeric> and C<binary> mean that the features' return values
should be converted into numbers or binary vectors, as for support vector
machines or neural networks to like them.

The return value is the list of what the features returned. In case of binary,
there can be a
different (typically greater) number of elements in the returned list than there
were features to evaluate.

=head3 Transfer to numeric / binary form

When you have the features output in numeric format, then integer and numeric
features are left alone and categorial ones have a natural number (starting with
1) assigned to every distinct value. If you use this feature, it is highly
recommended to specify the values for the feature. If you don't then
Data::FeatureFactory will attempt to create a mapping from the categories to numbers
dynamically as then feature is evaluated. The mapping is being saved to a file
whose name is C<.FeatureFactory.I<package_name>__I<feature_name>> and is located
in the directory where Data::FeatureFactory resides if possible, or in your home
directory or in /tmp - wherever the script can write. If none works, then you
get a fatal error. The mapping is restored and extended upon subsequent runs
with the same package and feature name, if read/write permissions don't change.

Binary format is such that the return value is converted to a vector of all 0's
and one 1. The positions in the vector represent the possible values of the
feature and 1 is on the position that the feature actually has in that
particular case. The values always need to be specified for this feature to work
and it is highly recommended that they be specified with a fixed order (not by a
hash), because else the order can change with different versions of perl and
when you change the set of values for the feature. And when the order changes,
then the meaning of the vectors change.

=head2 N/A values

You can specify a value to be substituted when a feature returns nothing (an
undefined value). This is passed as an argument to the C<new> method.

 $f = MyFeatures->new({ 'N/A' => '_' }); # MyFeatures inherits from Data::FeatureFactory
 $v = $f->evaluate('feature1', 'normal', 'unexpected_argument');

If C<feature1> returns an undefined value, then $v will contain the string '_'.
When evaluating in binary format, a vector of the usual length is returned, with
all values being the specified N/A. That is, if C<feature1> has 3 possible
values, then

 @v = $f->evaluate('feature1', 'binary', 'unexpected_argument');

will result in @v being C<('_', '_', '_')>. If C<feature1> returns undef, that
is.

=head1 COPYRIGHT

Copyright (c) 2008 Oldrich Kruza. All rights reserved.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

use strict;
use Carp;
use File::Basename;

our $VERSION = '0.01';
my $PATH = &{ sub { return dirname( (caller)[1] ) } };

sub new : method {
    croak 'Too many parameters' if @_ > 2;
    my ($class, $args) = @_;
    $class = ref $class if ref $class;
    my $self = bless +{}, $class;
    
    if (defined $args) {
        croak "The parameter to ${class}->new must be a hashref with options or nothing" if ref $args ne 'HASH';
        my %accepted_option = map {;$_=>1} qw(N/A);
        while (my ($k, $v) = each %$args) {
            if (not exists $accepted_option{$k}) {
                croak "Unexpected option '$k' passed to ${class}->new"
            }
            if ($k eq 'N/A') {
                $self->{'N/A'} = "$v";
            }
        }
    }
    
    no strict 'refs';
    if (not defined @{$class."::features"}) {
        croak "\@${class}::features not defined";
    }
    our @features;
    *features = \@{$class."::features"};
    use strict;
    if (not @features) {
        warn "$class has empty set of features. Not much fun";
    }
    $self->{'features'} = [];
    my %feat_named;
    $self->{'feat_named'} = \%feat_named;
    my @featkeys;
    $self->{'featkeys'} = \@featkeys;
    $self->{'caller_path'} = dirname( (caller)[1] );
    
    my %supported_option = ( map {;$_=>1} qw(code default format name postproc range type values values_file) );
    my %accepted_option  = ( map {;$_=>1} qw(cat2num cat2num_dyna num2cat num2cat_dyna num_values_fh values_ordered) );
    
    # parse the @features array
    for my $original_feature (@features) {
        my $feature = { %$original_feature };
        if (not exists $feature->{'name'}) {
            croak q{There was a feature without a name. Each record in the @features array must be a hashref with a 'name' field at least};
        }
        my $name = $feature->{'name'};
        if (exists $feat_named{$name}) {
            croak "Feature $name specified twice in \@${class}::features";
        }
        push @{ $self->{'features'} }, $feature;
        $feat_named{$name} = $feature;
        push @featkeys, $name;
        
        # Check if there aren't illegal options
        for (keys %$feature) {
            if (not exists $supported_option{$_}) {
                if (exists $accepted_option{$_}) {
                    warn "Option '$_' you specified for feature '$name' is not supported. Be sure you know what you are doing"
                }
                else {
                    croak "Unrecognized option '$_' specified for feature '$name'";
                }
            }
        }
        
        # Check if a postprocessing subroutine is declared
        # If it's a CODEref, we're OK. Else try to load it.
        if (exists $feature->{'postproc'} and ref $feature->{'postproc'} ne 'CODE') {
            my $postproc = $feature->{'postproc'};
            no strict 'refs';
            my $postprocsub = \&{$postproc};
            undef $@;
            eval { $postprocsub->() };
            if ($@ =~ /Undefined subroutine/) {
                my ($package_name) = $postproc =~ /^( (?: \w+:: )+ )/x;
                my $ppname;
                if (defined $package_name and length $package_name > 0) {
                    $package_name =~ s/::$//;
                    push @INC, $self->{'caller_path'};
                    undef $@;
                    eval "require $package_name";
                    if ($@) {
                        warn "Failed loading module '$package_name'";
                    }
                    $ppname = $postproc;
                }
                else {
                    $ppname = $class.'::'.$postproc;
                }
                $postprocsub = \&{$ppname};
                undef $@;
                eval { $postprocsub->() };
                if ($@) {
                    croak "Couldn't load postprocessing function '$postproc' ($@)"
                }
            }
            elsif ($@) {
                croak "Couldn't load postprocessing function '$postproc' ($@)"
            }
            $feature->{'postproc'} = $postprocsub;
        }
        
        # Check if values are specified and if they are a list of values.
        if (exists $feature->{'values'}) {
            if (exists $feature->{'values_file'}) {
                croak "Values specified both explicitly and by file for '$name'"
            }
            my $values = $feature->{'values'};
            if (ref $values eq 'HASH') {    # OK, do nothing
            }
            elsif (ref $values eq 'ARRAY') {    # Convert the list to a hash.
                my %values = map {;$_ => 1} @$values;
                $feature->{'values_ordered'} = $values;
                $feature->{'values'} = \%values;
            }
            else {
                my $type;
                if (ref $values) {
                    $type = lc(ref $values).'ref';
                }
                else {
                    $type = lc(ref \$values);
                }
                croak "The values must be specified as an arrayref or hashref, not $type"
            }
        }
        
        if (exists $feature->{'values_file'}) {
            my $values_fn = $feature->{'values_file'};
            my $opened = open my $values_fh, '<:encoding(utf8)', $values_fn;
            if (not $opened) {
                open $values_fh, '<:encoding(utf8)', $self->{'caller_path'}.'/'.$values_fn
                    or croak "Couldn't open file '$values_fn' specifying values for $name"
            }
            my %values;
            my @values;
            while (<$values_fh>) {
                chomp;
                $values{$_} = 1;
                push @values, $_;
            }
            close $values_fh;
            $feature->{'values'} = \%values;
            $feature->{'values_ordered'} = \@values;
        }
        
        if (exists $feature->{'range'}) {
            if (exists $feature->{'values'}) {
                croak "Both range and values specified for feature '$name'"
            }
            $feature->{'range'} =~ /^ (.+?) \s* \.{2,} \s* (.+) $/x
            or croak "Malformed range '$$feature{range}' of feature '$name'. Should be in format '0 .. 5'";
            my $l = $1+0;
            my $r = $2+0;
            if (not $l < $r) {
                croak "Invalid range '$$feature{range}' specified for feature '$name'. The left boundary must be lesser than the right one"
            }
            
            if ($feature->{'type'} eq 'int') {
                $feature->{'values'} = {map {;$_ => 1} $l .. $r};
                $feature->{'values_ordered'} = [$l .. $r];
            }
            elsif ($feature->{'type'} eq 'num') { 
                $feature->{'range_l'} = $l;
                $feature->{'range_r'} = $r;
            }
        }
        
        if (exists $feature->{'default'}) {
            if (not exists $feature->{'values'} and not exists $feature->{'range_l'}) {
                croak "Default value '$$feature{default}' but no values specified for feature '$name'"
            }
        }
        
        if (exists $feature->{'type'}) {
            my $type = lc substr $feature->{'type'}, 0, 3;
            my $type_OK = grep {$type eq $_} qw(boo int num cat);
            if (not $type_OK) {
                croak "The type of a feature, if given, should be 'integer', 'numeric', or 'categorial'"
            }
            $feature->{'type'} = $type;
            
            # check if the values comply to the type
            if ($type eq 'boo') {
                if (exists $feature->{'values'}) {
                    my @values = exists $feature->{'values_ordered'} ? @{ $feature->{'values_ordered'} } : values(%{ $feature->{'values'} });
                    if (@values > 2) {
                        my $num_values = @values;
                        croak "More than two values ($num_values) specified for feature '$name'"
                    }
                    my ($false, $true);
                    # boolify the values
                    for (@values) {
                        if ($_) {
                            if (defined $true) {
                                croak "True value (literal: '$true', '$_') for feature '$name' specified multiple times"
                            }
                            $true = $_;
                        }
                        else {
                            if (defined $false) {
                                croak "False value (literal: '$false', '$_') for feature '$name' specified multiple times"
                            }
                            $false = $_;
                        }
                        $_ = $_ ? 1 : 0;
                    }
                    if (exists $feature->{'values_ordered'}) {
                        $feature->{'values_ordered'} = \@values;
                    }
                    $feature->{'values'} = +{ map {;$_=>1} @values };
                }
                if (exists $feature->{'default'}) {
                    my $def = $feature->{'default'};
                    my @vals = values %{ $feature->{'values'} };
                    if (@vals > 1) {
                        croak "Default value '$def' specified for boolean feature '$name' which has both values allowed"
                    }
                    unless ($def xor $vals[0]) {
                        my $val = $def ? 'true' : 'false';
                        croak "Default and allowed value are both $val for feature '$name'";
                    }
                    $feature->{'default'} = $def ? 1 : 0;
                }
            }
            elsif ($type eq 'int') {
                if (exists $feature->{'values'}) {
                    my @values = exists $feature->{'values_ordered'} ? @{ $feature->{'values_ordered'} } : values(%{ $feature->{'values'} });
                    # integrify the values
                    for (@values) {
                        $_ = int $_;
                    }
                    if (exists $feature->{'values_ordered'}) {
                        $feature->{'values_ordered'} = \@values;
                    }
                    $feature->{'values'} = +{ map {;$_=>1} @values };
                }
                if (exists $feature->{'default'}) {
                    $feature->{'default'} = int $feature->{'default'};
                }
            }
            elsif ($type eq 'num') {
                # numify the features, producing warnings if used
                if (exists $feature->{'values'}) {
                    my @values = exists $feature->{'values_ordered'} ? @{ $feature->{'values_ordered'} } : values(%{ $feature->{'values'} });
                    for (@values) {
                        $_ += 0;
                    }
                    if (exists $feature->{'values_ordered'}) {
                        $feature->{'values_ordered'} = \@values;
                    }
                    $feature->{'values'} = +{ map {;$_=>1} @values };
                }
                if (exists $feature->{'default'}) {
                    $feature->{'default'} += 0;
                }
            }
        }
        
        # There are more problems with this feature than I had thought. It's not going to be implemented soon.
        # Add the optional N/A value to accepted values
        if (0 and exists $self->{'N/A'} and exists $feature->{'values'} and not exists $feature->{'values'}{ $self->{'N/A'} }) {
            my $na = $self->{'N/A'};
            $feature->{'values'}{$na} = 1;
            if (exists $feature->{'values_ordered'}) {
                push @{ $feature->{'values_ordered'} }, $na;
            }
        }
        
        if (exists $feature->{'format'}) {
            my $format = $feature->{'format'};
            if (not $format =~ /^ (?: normal | numeric | binary ) $/x) {
                croak "Invalid format '$format' specified for feature '$name'. Please specify 'normal', 'numeric' or 'binary'"
            }
            if (not exists $feature->{'values'} and $format eq 'binary') {
                croak "Feature '$name' has format: 'binary' specified but doesn't have values specified"
            }
        }
        
        # find the actual code of the feature
        my $code;
        no strict 'refs';
        if (exists $feature->{'code'}) {
            $code = $feature->{'code'};
            if (ref $code ne 'CODE') {
                croak "'code' was specified for feature '$name' but it's not a coderef"
            }
        }
        elsif (%{$class.'::features'} and exists ${$class.'::features'}{$name}) {
            $code = ${$class.'::features'}{$name};
            if (ref $code ne 'CODE') {
                croak "Found $name in \%${class}::features but it's not a coderef"
            }
        }
        else {
            $code = *{$class.'::'.$name}{CODE};
            if (ref $code ne 'CODE') {
                croak "Couldn't find the code (function) for feature '$name'. Define it as a function '$name' in the '$class' package"
            }
        }
        $feature->{'code'} = $code;
    }
#    print map "*$_\n", map keys(%$_), @{ $self->{'features'} };
    return $self
}

sub evaluate : method {
    my ($self, $featnames, $format, @args) = @_;
    my $class = ref $self;
    my @featkeys = @{ $self->{'featkeys'} };
    my %feat_named = %{ $self->{'feat_named'} };
    
    if ($featnames eq 'ALL') {
        $featnames = \@featkeys;
    }
    elsif (ref $featnames eq 'ARRAY') {
    }
    else {
        $featnames = ["$featnames"];
    }
    my @feats;
    for my $featname (@$featnames) {
        if (not exists $feat_named{$featname}) {
            croak "Feature '$featname' you wish to evaluate was not found among known features (these are: @featkeys)"
        }
        push @feats, $feat_named{$featname};
    }
    
    if ($format !~ /^ (?: normal | numeric | binary ) $/x) {
        croak "Unknown format: '$format'. Please specify 'normal', 'numeric' or 'binary'"
    }
    for my $feature (@feats) {
        $self->_create_mapping($feature, $format);
    }
    
    if (@args == 0) {
        warn 'No arguments specified for the features.';
    }
    ### Done argument checking.
    
    ### Traverse the features and evaluate them
    my @rv;
    for my $feature (@feats) {
        my $name = $feature->{'name'};
        my $normrv = $feature->{'code'}(@args);
        my $format = exists $feature->{'format'} ? $feature->{'format'} : $format;
        
        if (not defined $normrv and exists $self->{'N/A'}) {
            my $na = $self->{'N/A'};
            if ($format eq 'binary') {
                # take one of the vectors in cat2bin
                my @dummy = @{ (values %{ $feature->{'cat2bin'} })[0] };
                if (not @dummy) {
                    croak "Couldn't determine the length of bit vector for feature '$name',"
                         ."which was about to be evaluated in binary and returned undef"
                }
                push @rv, map $na, @dummy;
            }
            else {
                push @rv, $na;
            }
        }
        else {
            # Normally format the value. The eval babble is there to take care of unexpected values.
            undef $@;
            my @val = eval { _format_value($feature, $normrv, $format, @args) };
            if ($@) {
                if (ref $@ and $@->isa('SoftError')) {
                    warn ${$@};
                    return
                }
                else {
                    die $@
                }
            }
            push @rv, @val;
        }
    }
    
    return @rv[0 .. $#rv]
}

sub _format_value {
    my ($feature, $normrv, $format, @args) = @_;
    my @rv;
    my $name = $feature->{'name'};
    
    # convert to number if appropriate
    if (exists $feature->{'type'}) {
        my $type = $feature->{'type'};
        if ($type eq 'num' or $type eq 'int') {
            $normrv += 0;
        }
        if ($type eq 'int') {
            $normrv = int $normrv;
        }
        if ($type eq 'boo') {
            $normrv = $normrv ? 1 : 0;
        }
    }
    
    # check if the value is a legal one
    if (exists $feature->{'values'}) {
        if (exists $feature->{'values'}{$normrv}) {    # alles gute
        }
        elsif (exists $feature->{'default'}) {
            $normrv = $feature->{'default'};
        }
        else {
            die SoftError->new("Feature '$name' returned unexpected value '$normrv' on arguments '@args'")
        }
    }
    # check the range for numeric features
    elsif (exists $feature->{'range_l'}) {
        if (not exists $feature->{'range_r'}) {
            die "feature '$name' has range_l but not range_r";
        }
        if ($normrv < $feature->{'range_l'}) {
            if (exists $feature->{'default'}) {
                $normrv = $feature->{'default'};
            }
            else {
                die SoftError->new("Feature '$name' returned an unexpected value '$normrv' below the left allowed boundary '$$feature{range_l}'")
            }
        }
        if ($normrv > $feature->{'range_r'}) {
            if (exists $feature->{'default'}) {
                $normrv = $feature->{'default'};
            }
            else {
                die SoftError->new("Feature '$name' returned an unexpected value '$normrv' above the right allowed boundary '$$feature{range_r}'")
            }
        }
    }
    
    if ($format eq 'normal') {
        if (exists $feature->{'postproc'}) {
            $normrv = $feature->{'postproc'}->($normrv);
        }
        @rv = ($normrv);
    }
    elsif ($format eq 'numeric') {
        if (exists $feature->{'type'} and $feature->{'type'} =~ /^( num | int | boo )$/x) {
            @rv = ($normrv);
        }
        elsif (exists $feature->{'cat2num'}) {
            if (not exists $feature->{'cat2num'}{$normrv}) {
                croak "Feature '$name' has the value '$normrv' for which there is no mapping to numbers"
            }
            @rv = ($feature->{'cat2num'}{$normrv});
        }
        else {  # dynamically creating the mapping
            my $n;
            if (exists $feature->{'cat2num_dyna'}{$normrv}) {
                $n = $feature->{'cat2num_dyna'}{$normrv};
            }
            else {
                $n = ++$feature->{'num_value_max'};
                $feature->{'cat2num_dyna'}{$normrv} = $n;
                $feature->{'num2cat_dyna'}{$n} = $normrv;
                print {$feature->{'num_values_fh'}} $normrv, "\t", $n, "\n"
                or croak "Couldn't print the mapping of categorial value '$normrv' to numeric value '$n' for feature '$name' to a file ($!).\nPlease provide a list of values for the feature to avoid this";
            }
            @rv = ($n);
        }
    }
    elsif ($format eq 'binary') {
        if (exists $feature->{'type'} and $feature->{'type'} eq 'boo') {
            @rv = ($normrv);
        }
        elsif (not exists $feature->{'cat2bin'}{$normrv}) {
            croak "No mapping for value '$normrv' to binary in feature '$name'"
        }
        else {
            @rv = @{ $feature->{'cat2bin'}{$normrv} };
        }
    }
    else {
        croak "Unrecognized format '$format'"
    }
    return @rv
}

sub _create_mapping : method {
    my ($class, $feature, $format) = @_;
    $class = ref $class if ref $class;
    if (exists $feature->{'format'}) {
        $format = $feature->{'format'};
    }
    
    if (lc $format eq 'normal') {
    }
    elsif (lc $format eq 'numeric') {
        return if exists $feature->{'type'} and $feature->{'type'} eq 'num';
        return if exists $feature->{'type'} and $feature->{'type'} eq 'int';
        return if exists $feature->{'type'} and $feature->{'type'} eq 'boo';
        return if exists $feature->{'cat2num'}; # Blindly trusting that what we have here is a sane mapping from the original values to numbers
        my $name = $feature->{'name'};
        if (not exists $feature->{'values'}) {
            return if exists $feature->{'num_values_fh'};
            warn "Categorial feature '$name' is about to be evaluated numerically but has no set of values specified";
            (my $num_values_basename = $class.'__'.$name) =~ s/\W/_/g;
            $num_values_basename = '.FeatureFactory.'.$num_values_basename;
            my @filenames_to_try = (
                $PATH.'/'.$num_values_basename,
                $ENV{'HOME'}.'/'.$num_values_basename,
                '/tmp/'.$num_values_basename,
            );
            my $num_values_fh;
            my $opened;
            my $num_value_max = 0;
            FILENAME_R:
            for my $fn (@filenames_to_try) {
                $opened = open my $fh, '+<:encoding(utf8)', $fn;
                if ($opened) {
                    local $_;   # for some reason, this is necessary to prevent crashes (Modification of read-only value) when e.g. in for(qw(a b)){ }
                    while (<$fh>) {
                        chomp;
                        my ($cat, $num) = split /\t/;
                        $num_value_max = $num if $num > $num_value_max;
                        $feature->{'cat2num_dyna'}{$cat} = $num;
                        $feature->{'num2cat_dyna'}{$num} = $cat;
                    }
                    print STDERR "Saving the mapping for feature '$name' to file $fn\n";
                    $feature->{'num_values_fh'} = $fh;
                    last FILENAME_R
                }
            }
            # If there's no file to recover from, try to start a new one
            if (not $opened) { FILENAME_W: for my $fn (@filenames_to_try) {
                $opened = open my $fh, '>:encoding(utf8)', $fn;
                if ($opened) {
                    print STDERR "Saving the mapping for feature '$name' to file $fn\n";
                    $feature->{'num_values_fh'} = $fh;
                    last FILENAME_W
                }
            }}
            if (not $opened) {
                delete $feature->{'num_values_fh'};
                croak "Couldn't open a file for saving the mapping the categories of feature '$name' to numbers. Please specify the values for the feature to avoid this"
            }
            $feature->{'num_value_max'} = $num_value_max;
        }
        else {  # Got values specified - create a mapping
            my @values;
            if (exists $feature->{'values_ordered'}) {
                @values = @{ $feature->{'values_ordered'} };
            }
            else {
                @values = keys %{ $feature->{'values'} };
            }
            if (exists $feature->{'default'} and not exists $feature->{'values'}{ $feature->{'default'} }) {
                push @values, $feature->{'default'};
            }
            my $n = 1;
            for my $value (@values) {
                $feature->{'cat2num'}{$value} = $n;
                $feature->{'num2cat'}{$n} = $value;
            } continue {
                $n++;
            }
        }
    }
    elsif (lc $format eq 'binary') {
        return if exists $feature->{'type'} and $feature->{'type'} eq 'boo';
        return if exists $feature->{'cat2bin'};
        my $name = $feature->{'name'};
        if (not exists $feature->{'values_ordered'} and not exists $feature->{'values'}) {
            croak "Attempted to convert feature '$name' to binary without specifying its values";
        }
        
        my @values;
        if (exists $feature->{'values_ordered'}) {
            @values = @{ $feature->{'values_ordered'} };
        }
        else {
            @values = keys %{ $feature->{'values'} };
        }
        if (exists $feature->{'default'} and not exists $feature->{'values'}{ $feature->{'default'} }) {
            push @values, $feature->{'default'};
        }
        
        my $n = 0;
        my @zeroes = (0) x scalar(@values);
        for my $value (@values) {
            my @vector = @zeroes;
            $vector[$n] = 1;
            $feature->{'cat2bin'}{$value} = \@vector;
            $feature->{'bin2cat'}{join(' ', @vector)} = $value;
        } continue {
            $n++;
        }
    }
    else {
        croak "Format '$format' not recognized - please specify 'normal', 'numeric' or 'binary' (should have caught this earlier)"
    }
}

# to delete
sub spit {
    my ($self, $featname) = @_;
    use Data::Dumper;
    return(Dumper($self->{'feat_named'}{$featname}))
}

{
    package SoftError;
    sub new {
        my ($class, $message) = @_;
        $message = "SoftError occurred" if not defined $message;
        return bless \$message, $class
    }
}

1
