#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

our $F;
my $gapbin = "/scratch/pgopalan/hgaprec/src/hgaprec";
my $ldabin = "/scratch/pgopalan/lda-c-dist/lda";
my $lda_settings_file = "/scratch/pgopalan/lda-c-dist/settings.txt";
my $batch_rfreq = 10;
my $online_rfreq = 10000;
my $ml_online_rfreq = 100;
my $dataset  = "";
my $bias = 0;
my $novb = 0;
my $orig = 0;
my %nf = ();
my %nyt = ();
my %ml = ();
my %dy = ();
my %en = ();
my $binary = 0;

sub init() {
    my $binstr = "";
    if (!$binary) {
	$binstr = "batch-vb-lda-write-training";
    } else {
	$binstr = "batch-bin-vb-lda-write-training";
    }
    
    $nf{loc} = "/scratch/pgopalan/hgaprec/analysis/data/netflix";
    $nf{N} = 40000; #480189;
    $nf{M} = 1800; #17770;
    $nf{batch_cmd} = "$gapbin  -dir $nf{loc} -m $nf{M} -n $nf{N} -k %d -rfreq $batch_rfreq -rating-threshold 4";
    $nf{gen_ranking_cmd} = "$gapbin -dir $nf{loc} -m $nf{M} -n $nf{N} -k %d -gen-ranking -rating-threshold 4";
    $nf{lda_write_cmd} = "$gapbin -dir $nf{loc} -m $nf{M} -n $nf{N} -k %d -lda -write-training -rating-threshold 4";
    $nf{lda_cp_cmd} = "cp $lda_settings_file n$nf{N}-m$nf{M}-k%d-$binstr;";
    $nf{lda_cmd} = "cd n$nf{N}-m$nf{M}-k%d-$binstr; $ldabin est %0.3f %d settings.txt ldatrain.tsv random lda-output";
    $nf{lda_precision_cmd} = "cd n$nf{N}-m$nf{M}-k%d-$binstr; cp lda-output/%s.gamma gamma.tsv; cp lda-output/%s.beta beta.tsv; $gapbin -dir $nf{loc} -m $nf{M} -n $nf{N} -k %d -lda -rating-threshold 1";
    $nf{nmf_cmd} = "$gapbin  -dir $nf{loc} -m $nf{M} -n $nf{N} -k %d -rfreq $batch_rfreq -rating-threshold 4 -nmf";
    $nf{nmf_precision_cmd} = "$gapbin  -dir $nf{loc} -m $nf{M} -n $nf{N} -k %d -rfreq $batch_rfreq -rating-threshold 4 -nmfload -nmf";

    $nyt{loc} = "/scratch/pgopalan/hgaprec/analysis/data/nyt";
    $nyt{N} = 160000; #1615675;
    $nyt{M} = 10000; #107523;
    $nyt{batch_cmd} = "$gapbin -dir $nyt{loc} -m $nyt{M} -n $nyt{N} -k %d -rfreq $batch_rfreq -rating-threshold 1";
    $nyt{gen_ranking_cmd} = "$gapbin -dir $nyt{loc} -m $nyt{M} -n $nyt{N} -k %d -gen-ranking -rating-threshold 1";
    $nyt{lda_write_cmd} = "$gapbin -dir $nyt{loc} -m $nyt{M} -n $nyt{N} -k %d -lda -write-training -rating-threshold 1";
    $nyt{lda_cp_cmd} = "cp $lda_settings_file n$nyt{N}-m$nyt{M}-k%d-$binstr;";
    $nyt{lda_cmd} = "cd n$nyt{N}-m$nyt{M}-k%d-$binstr; $ldabin est %0.3f %d settings.txt ldatrain.tsv random lda-output";
    $nyt{lda_precision_cmd} = "cd n$nyt{N}-m$nyt{M}-k%d-$binstr; cp lda-output/%s.gamma gamma.tsv; cp lda-output/%s.beta beta.tsv; $gapbin -dir $nyt{loc} -m $nyt{M} -n $nyt{N} -k %d -lda -rating-threshold 1";
    $nyt{nmf_cmd} = "$gapbin -dir $nyt{loc} -m $nyt{M} -n $nyt{N} -k %d -rfreq $batch_rfreq -rating-threshold 1 -nmf";
    $nyt{nmf_precision_cmd} = "$gapbin -dir $nyt{loc} -m $nyt{M} -n $nyt{N} -k %d -rfreq $batch_rfreq -rating-threshold 1 -nmfload -nmf";

    $ml{loc} = "/scratch/pgopalan/hgaprec/analysis/data/movielens";
    $ml{N} = 6040;
    $ml{M} = 3681;
    $ml{batch_cmd} = "$gapbin  -dir $ml{loc} -m $ml{M} -n $ml{N} -k %d -rfreq $batch_rfreq -rating-threshold 4";
    $ml{gen_ranking_cmd} = "$gapbin -dir $ml{loc} -m $ml{M} -n $ml{N} -k %d -gen-ranking -rating-threshold 4";
    $ml{lda_write_cmd} = "$gapbin -dir $ml{loc} -m $ml{M} -n $ml{N} -k %d -lda -write-training -rating-threshold 4";
    $ml{lda_cp_cmd} = "cp $lda_settings_file n$ml{N}-m$ml{M}-k%d-$binstr;";
    $ml{lda_cmd} = "cd n$ml{N}-m$ml{M}-k%d-$binstr; $ldabin est %0.3f %d settings.txt ldatrain.tsv random lda-output";
    $ml{lda_precision_cmd} = "cd n$ml{N}-m$ml{M}-k%d-$binstr; cp lda-output/%s.gamma gamma.tsv; cp lda-output/%s.beta beta.tsv; $gapbin -dir $ml{loc} -m $ml{M} -n $ml{N} -k %d -lda -rating-threshold 1";
    $ml{nmf_cmd} = "$gapbin  -dir $ml{loc} -m $ml{M} -n $ml{N} -k %d -rfreq $batch_rfreq -rating-threshold 4 -nmf";
    $ml{nmf_precision_cmd} = "$gapbin  -dir $ml{loc} -m $ml{M} -n $ml{N} -k %d -rfreq $batch_rfreq -rating-threshold 4 -nmfload -nmf";

    $dy{loc} = "/scratch/pgopalan/hgaprec/analysis/data/mendeley";
    $dy{N} = 8000; #80278;
    $dy{M} = 20000; #261248;
    $dy{batch_cmd} = "$gapbin -dir $dy{loc} -m $dy{M} -n $dy{N} -k %d -rfreq $batch_rfreq -rating-threshold 1";
    $dy{gen_ranking_cmd} = "$gapbin -mendeley -dir $dy{loc} -m $dy{M} -n $dy{N} -k %d -gen-ranking -rating-threshold 1";
    $dy{lda_write_cmd} = "$gapbin -dir $dy{loc} -m $dy{M} -n $dy{N} -k %d -lda -write-training -rating-threshold 1";
    $dy{lda_cp_cmd} = "cp $lda_settings_file n$dy{N}-m$dy{M}-k%d-$binstr;";
    $dy{lda_cmd} = "cd n$dy{N}-m$dy{M}-k%d-$binstr; $ldabin est %0.3f %d settings.txt ldatrain.tsv random lda-output";
    $dy{lda_precision_cmd} = "cd n$dy{N}-m$dy{M}-k%d-$binstr; cp lda-output/%s.gamma gamma.tsv; cp lda-output/%s.beta beta.tsv; $gapbin -dir $dy{loc} -m $dy{M} -n $dy{N} -k %d -lda -rating-threshold 1";
    $dy{nmf_cmd} = "$gapbin -dir $dy{loc} -m $dy{M} -n $dy{N} -k %d -rfreq $batch_rfreq -rating-threshold 1 -nmf";
    $dy{nmf_precision_cmd} = "$gapbin -dir $dy{loc} -m $dy{M} -n $dy{N} -k %d -rfreq $batch_rfreq -rating-threshold 1 -nmfload -nmf";

    $en{loc} = "/scratch/pgopalan/hgaprec/analysis/data/echonest";
    $en{N} = 100000; #1019318;
    $en{M} = 40000; #384546;
    $en{batch_cmd} = "$gapbin  -dir $en{loc} -m $en{M} -n $en{N} -k %d -rfreq $batch_rfreq -rating-threshold 1";
    $en{gen_ranking_cmd} = "$gapbin -dir $en{loc} -m $en{M} -n $en{N} -k %d -gen-ranking -rating-threshold 1";
    $en{lda_write_cmd} = "$gapbin -dir $en{loc} -m $en{M} -n $en{N} -k %d -lda -write-training -rating-threshold 1";
    $en{lda_cp_cmd} = "cp $lda_settings_file n$en{N}-m$en{M}-k%d-$binstr;";
    $en{lda_cmd} = "cd n$en{N}-m$en{M}-k%d-$binstr; $ldabin est %0.3f %d settings.txt ldatrain.tsv random lda-output";
    $en{lda_precision_cmd} = "cd n$en{N}-m$en{M}-k%d-$binstr; cp lda-output/%s.gamma gamma.tsv; cp lda-output/%s.beta beta.tsv; $gapbin -dir $en{loc} -m $en{M} -n $en{N} -k %d -lda -rating-threshold 1";
    $en{nmf_cmd} = "$gapbin  -dir $en{loc} -m $en{M} -n $en{N} -k %d -rfreq $batch_rfreq -rating-threshold 1 -nmf";
    $en{nmf_precision_cmd} = "$gapbin  -dir $en{loc} -m $en{M} -n $en{N} -k %d -rfreq $batch_rfreq -rating-threshold 1 -nmfload -nmf";
}

my $label = "";
my $seed = 0;
my $hyp = 0;
my $K = 25;
my $online = 0;
my $gen = 0;
my $hier = 0;
my $lda = 0;
my $ldaprec = 0;
my $logl = 0;
my $nmf = 0;
my $nmfload = 0;

sub run($) {
    my $a = shift @_;
    print $F "CMD = $a\n";
    if (system("$a 2>&1 > /dev/null &") != 0) { 
	print $F "$a failed\n";
	return -1;
    }
    return 0;
}

sub run2($) {
    my $a = shift @_;
    print $F "CMD = $a\n";
    if (system("$a") != 0) { 
	print $F "$a failed\n";
	return -1;
    }
    return 0;
}

sub main()
{
    GetOptions ('label=s' => \$label,
		'hyp' => \$hyp,
		'K=i' => \$K,
		'online' => \$online,
		'dataset=s' => \$dataset,
		'seed=i' => \$seed,
		'binary' => \$binary,
		'bias' => \$bias,
		'hier' => \$hier,
		'gen' => \$gen,
		'novb' => \$novb,
		'lda' => \$lda,
		'ldaprec' => \$ldaprec,
		'orig' => \$orig,
		'logl' => \$logl,
		'nmf' => \$nmf,
		'nmfload' => \$nmfload);

    if ($orig) {
	$gapbin = "/scratch/pgopalan/gaprec/src/gaprec";
    }
    
    open $F, ">>cmds.txt";
    init();

    my $m = \%nf;
    if ($dataset eq "movielens") {
	$m = \%ml;
    } elsif ($dataset eq "mendeley") {
	$m = \%dy;
    } elsif ($dataset eq "echonest") {
	$m = \%en;
    } elsif ($dataset eq "nyt") {
	$m = \%nyt;
    }
    if ($nmfload) {
	my $cmd = sprintf $m->{nmf_precision_cmd}, $K;
	$cmd = process($cmd);
	run($cmd);
    } elsif ($nmf) {
	my $cmd = sprintf $m->{nmf_cmd}, $K;
	$cmd = process($cmd);
	run($cmd);
    } elsif ($ldaprec) {
	my $cmd = sprintf $m->{lda_precision_cmd}, $K, "final", "final", $K;
	$cmd = process($cmd);
	run($cmd);
    } elsif ($lda) {
	my $cmd = sprintf $m->{lda_write_cmd}, $K;
	$cmd = process($cmd);
	run2($cmd);
	$cmd = sprintf $m->{lda_cp_cmd}, $K;
	run2($cmd);
	my $alpha = 1.0 / $K;
	$cmd = sprintf $m->{lda_cmd}, $K, $alpha, $K;
	run($cmd);	
    } elsif (!$online && !$gen) {
	my $cmd = sprintf $m->{batch_cmd}, $K;
	$cmd = process($cmd);
	run($cmd);
    } elsif ($gen) {
	my $cmd = sprintf $m->{gen_ranking_cmd}, $K;
	$cmd = process($cmd);
	run($cmd);
    } else {
	my $cmd = sprintf $m->{online_cmd}, $K;
	$cmd = process($cmd);
	run($cmd);
    }
}

sub process($) {
    my $cmd = shift @_;
    if ($hyp) {
	my $v = 0.01;
	$cmd .= " -a $v -b 1 -c $v -d 1";
    }
    if ($label) {
	$cmd .= " -label $label";
    }
    if ($seed) {
	$cmd .= " -seed $seed";
    }
    if ($binary) {
	$cmd .= " -binary-data";
    }
    if ($bias) {
	$cmd .= " -bias";
    }
    if ($hier) {
	$cmd .= " -hier";
    }
    if ($novb) {
	$cmd .= " -novb";
    }
    if ($logl) {
	$cmd .= " -logl";
    }
    return $cmd;
}

main();
