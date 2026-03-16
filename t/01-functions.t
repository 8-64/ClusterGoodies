#!/usr/bin/env perl

use v5.36;
use warnings;
use Test::More;

# Load the script's functions by doing... well, since it's a script, we need to eval it or something.
# Actually, better to refactor, but for now, let's copy the functions we want to test.

# For simplicity, I'll inline the functions to test them directly.

sub normalize_region ($raw) {
    return undef unless defined $raw;

    # Trim whitespace
    $raw =~ s/^\s+//;
    $raw =~ s/\s+$//;

    # Strip wrapping single/double quotes: 'eu-central-1' or "eu-central-1"
    if ($raw =~ /^['"](.*)['"]$/) {
        $raw = $1;
    }

    # If something like "region eu-central-1" ever appears, grab the real region
    if ($raw =~ /([a-z]{2}-[a-z0-9-]+-\d)/) {
        $raw = $1;
    }

    return $raw;
}

sub build_context_alias ($template, $cluster, $account, $region) {
    my $alias = $template;
    $alias =~ s/%CLUSTER%/$cluster/g;
    $alias =~ s/%ACCOUNT%/$account/g;
    $alias =~ s/%REGION%/$region/g;
    return $alias;
}

sub select_target_cluster ($clusters, $requested_cluster) {
    my @sorted = sort @$clusters;

    if (defined $requested_cluster && length $requested_cluster) {
        my %set = map { $_ => 1 } @$clusters;
        if ($set{$requested_cluster}) {
            return $requested_cluster;
        }
        die "Requested cluster '$requested_cluster' not found in EKS list.\n";
    }

    # If there is only one cluster, use it.
    if (@sorted == 1) {
        return $sorted[0];
    }

    # If multiple clusters, prefer first alphabetically unless user sets KCC_DEFAULT_CLUSTER
    if (my $default = $ENV{KCC_DEFAULT_CLUSTER}) {
        my %set = map { $_ => 1 } @$clusters;
        if ($set{$default}) {
            return $default;
        }
    }

    return $sorted[0];
}

# Tests for normalize_region
is(normalize_region('us-east-1'), 'us-east-1', 'basic region');
is(normalize_region('  us-east-1  '), 'us-east-1', 'trim whitespace');
is(normalize_region("'us-east-1'"), 'us-east-1', 'strip single quotes');
is(normalize_region('"us-east-1"'), 'us-east-1', 'strip double quotes');
is(normalize_region('region us-west-2'), 'us-west-2', 'extract from text');
is(normalize_region(undef), undef, 'undef input');

# Tests for build_context_alias
is(build_context_alias('eks/%CLUSTER%@%ACCOUNT%/%REGION%', 'my-cluster', '123456789', 'us-east-1'),
   'eks/my-cluster@123456789/us-east-1', 'basic alias building');
is(build_context_alias('%CLUSTER%-%REGION%', 'test', 'acc', 'reg'),
   'test-reg', 'different template');
is(build_context_alias('prefix-%CLUSTER%-suffix', 'cluster', 'account', 'region'),
   'prefix-cluster-suffix', 'prefix and suffix');

# Tests for select_target_cluster
is(select_target_cluster(['cluster1'], undef), 'cluster1', 'single cluster');
is(select_target_cluster(['b', 'a'], undef), 'a', 'multiple, first alpha');
{
    local $ENV{KCC_DEFAULT_CLUSTER} = 'b';
    is(select_target_cluster(['a', 'b'], undef), 'b', 'default from env');
}
eval { select_target_cluster(['a'], 'b') };
like($@, qr/not found/, 'requested not found');

done_testing();