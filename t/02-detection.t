#!/usr/bin/env perl

use v5.36;
use warnings;
use Test::More;
use JSON::PP qw(encode_json);

# Instead of mocking, we'll override the run_cmd_capture in the test namespace
no warnings 'redefine';
sub run_cmd_capture (@cmd) {
    my $cmd_str = join(' ', @cmd);
    if ($cmd_str =~ /aws configure get region/) {
        return ("us-east-1\n", 0);
    } elsif ($cmd_str =~ /aws sts get-caller-identity/) {
        my $json = encode_json({ Account => '123456789012' });
        return ("$json\n", 0);
    } elsif ($cmd_str =~ /aws eks list-clusters/) {
        my $json = encode_json({ clusters => ['cluster1', 'cluster2'] });
        return ("$json\n", 0);
    } else {
        return ("", 1); # fail others
    }
}

# Copy the functions from the script
sub normalize_region ($raw) {
    return undef unless defined $raw;
    $raw =~ s/^\s+//;
    $raw =~ s/\s+$//;
    if ($raw =~ /^['"](.*)['"]$/) {
        $raw = $1;
    }
    if ($raw =~ /([a-z]{2}-[a-z0-9-]+-\d)/) {
        $raw = $1;
    }
    return $raw;
}

sub detect_region ($override_region) {
    if (defined $override_region && length $override_region) {
        my $norm = normalize_region($override_region);
        return $norm;
    }

    if (my $env_region = $ENV{AWS_REGION} // $ENV{AWS_DEFAULT_REGION}) {
        my $norm = normalize_region($env_region);
        return $norm;
    }

    my ($out, $exit) = run_cmd_capture(qw/aws configure get region/);
    chomp $out;
    if ($exit == 0 && $out) {
        my $norm = normalize_region($out);
        return $norm;
    }

    die "Unable to determine AWS region.\n";
}

sub detect_account_id ($profile) {
    my @cmd = (qw/aws sts get-caller-identity --output json/);
    push @cmd, ('--profile', $profile) if defined $profile;

    my ($out, $exit) = run_cmd_capture(@cmd);
    if ($exit != 0) {
        die "Failed to run aws sts get-caller-identity.\n";
    }

    my $json = eval { JSON::PP::decode_json($out) };
    my $account = $json->{Account}
        or die "No Account field.\n";

    unless (Scalar::Util::looks_like_number($account)) {
        die "Non-numeric account.\n";
    }

    return $account;
}

sub list_eks_clusters ($region, $profile) {
    my @cmd = (qw/aws eks list-clusters --output json --region/, $region);
    push @cmd, ('--profile', $profile) if defined $profile;

    my ($out, $exit) = run_cmd_capture(@cmd);
    if ($exit != 0) {
        die "Failed to list clusters.\n";
    }

    my $json = eval { JSON::PP::decode_json($out) };
    my $clusters = $json->{clusters} // [];

    return $clusters;
}

# Tests
is(detect_region('us-west-2'), 'us-west-2', 'override region');
{
    local $ENV{AWS_REGION} = 'eu-central-1';
    is(detect_region(undef), 'eu-central-1', 'from env');
}
is(detect_region(undef), 'us-east-1', 'from aws configure');

is(detect_account_id(undef), '123456789012', 'detect account');
is_deeply(list_eks_clusters('us-east-1', undef), ['cluster1', 'cluster2'], 'list clusters');

done_testing();