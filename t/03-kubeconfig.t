#!/usr/bin/env perl

use v5.36;
use warnings;
use Test::More;
use JSON::PP qw(encode_json);

# Override run_cmd_capture
no warnings 'redefine';
sub run_cmd_capture (@cmd) {
    my $cmd_str = join(' ', @cmd);
    if ($cmd_str =~ /kubectl config view/) {
        my $kubeconfig = {
            contexts => [
                { name => 'context1', context => { cluster => 'cluster1' } },
                { name => 'eks/cluster2@123/us-east-1', context => { cluster => 'arn:aws:eks:us-east-1:123:cluster/cluster2' } }
            ],
            clusters => []
        };
        return (encode_json($kubeconfig), 0);
    } elsif ($cmd_str =~ /kubectl config current-context/) {
        return ("context1\n", 0);
    } else {
        return ("", 0);
    }
}

# Copy functions
sub get_kubeconfig_json () {
    my (@cmd) = qw/kubectl config view -o json/;
    my ($out, $exit) = run_cmd_capture(@cmd);

    if ($exit != 0) {
        return { contexts => [], clusters => [] };
    }

    return eval { JSON::PP::decode_json($out) };
}

sub get_current_context_name ($kube) {
    my @contexts = @{ $kube->{contexts} // [] };
    my ($out, $exit) = run_cmd_capture(qw/kubectl config current-context/);
    if ($exit != 0) {
        return undef;
    }
    chomp $out;
    return $out if $out;

    if (@contexts == 1) {
        return $contexts[0]{name};
    }

    return undef;
}

sub get_cluster_name_for_context ($kube, $context_name) {
    if ($context_name =~ m{arn:aws:eks:[^:]+:[^:]+:cluster/(.+)}) {
        return $1;
    }

    my @contexts = @{ $kube->{contexts} // [] };
    my ($ctx) = grep { $_->{name} // '' eq $context_name } @contexts;
    return undef unless $ctx;

    my $cluster_ref_name = $ctx->{context}{cluster};
    return undef unless $cluster_ref_name;

    my $name = $cluster_ref_name;
    if ($name =~ m{/}) {
        $name = (split m{/}, $name)[-1];
    }
    return $name;
}

sub find_context_for_cluster ($kube, %args) {
    my $target_cluster = $args{cluster_name};
    my $alias          = $args{alias};

    my @contexts = @{ $kube->{contexts} // [] };

    if (defined $alias) {
        for my $ctx (@contexts) {
            next unless defined $ctx->{name};
            return $ctx->{name} if $ctx->{name} eq $alias;
        }
    }

    for my $ctx (@contexts) {
        my $ctx_name = $ctx->{name} // next;
        my $cluster_ref = $ctx->{context}{cluster} // next;

        my $name = $cluster_ref;
        $name = (split m{/}, $name)[-1] if $name =~ m{/};

        if ($name eq $target_cluster) {
            return $ctx_name;
        }
    }

    return undef;
}

# Tests
my $kube = get_kubeconfig_json();
is(get_current_context_name($kube), 'context1', 'current context');
is(get_cluster_name_for_context($kube, 'context1'), 'cluster1', 'cluster for context');
is(get_cluster_name_for_context($kube, 'arn:aws:eks:us-east-1:123:cluster/cluster2'), 'cluster2', 'cluster from ARN');
is(find_context_for_cluster($kube, cluster_name => 'cluster2'), 'eks/cluster2@123/us-east-1', 'find context by cluster');
is(find_context_for_cluster($kube, cluster_name => 'cluster1', alias => 'alias1'), 'context1', 'find by cluster when alias not found');

done_testing();