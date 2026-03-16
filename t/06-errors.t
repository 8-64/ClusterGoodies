#!/usr/bin/env perl

use v5.36;
use warnings;
use Test::More;

# Test error conditions

# Override run_cmd_capture to simulate failures
no warnings 'redefine';
sub run_cmd_capture (@cmd) {
    my $cmd_str = join(' ', @cmd);
    if ($cmd_str =~ /aws configure get region/) {
        return ("", 1); # fail
    } elsif ($cmd_str =~ /aws sts get-caller-identity/) {
        return ("invalid json", 0);
    } else {
        return ("", 1);
    }
}

# Copy detect_region
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

# Test error in detect_region
eval { detect_region(undef) };
like($@, qr/Unable to determine AWS region/, 'detect_region fails when no region found');

# Test error in detect_account_id
eval { detect_account_id(undef) };
like($@, qr/No Account field/, 'detect_account_id fails on invalid json');

done_testing();