sample = config["parameters"]["sample"],
min_var_length = config["parameters"]["min_var_length"],
max_var_length = config["parameters"]["max_var_length"]

# iGenVar
rule copy_igenvar_results:
    output:
        res_S = "results/caller_comparison_short_read/{dataset}/eval/iGenVar_S/no_DUP_and_INV.min_qual_{min_qual}/pr_rec.txt",
        res_SL1 = "results/caller_comparison_short_read/{dataset}/eval/iGenVar_SL1/no_DUP_and_INV.min_qual_{min_qual}/pr_rec.txt",
        res_SL2 = "results/caller_comparison_short_read/{dataset}/eval/iGenVar_SL2/no_DUP_and_INV.min_qual_{min_qual}/pr_rec.txt",
        res_SL3 = "results/caller_comparison_short_read/{dataset}/eval/iGenVar_SL3/no_DUP_and_INV.min_qual_{min_qual}/pr_rec.txt"
    threads: 1
    run:
        if wildcards.dataset == 'Illumina_Paired_End':
            shell("""
            cp -r results/caller_comparison_iGenVar_only/eval/S1/no_DUP_and_INV.min_qual_{wildcards.min_qual} \
                results/caller_comparison_short_read/Illumina_Paired_End/eval/iGenVar_S/
            """)
            shell("""
            cp -r results/caller_comparison_iGenVar_only/eval/S1L1/no_DUP_and_INV.min_qual_{wildcards.min_qual} \
                results/caller_comparison_short_read/Illumina_Paired_End/eval/iGenVar_SL1/
            """)
            shell("""
            cp -r results/caller_comparison_iGenVar_only/eval/S1L2/no_DUP_and_INV.min_qual_{wildcards.min_qual} \
                results/caller_comparison_short_read/Illumina_Paired_End/eval/iGenVar_SL2/
            """)
            shell("""
            cp -r results/caller_comparison_iGenVar_only/eval/S1L3/no_DUP_and_INV.min_qual_{wildcards.min_qual} \
                results/caller_comparison_short_read/Illumina_Paired_End/eval/iGenVar_SL3/
            """)
            shell("""
                sed -i 's/S1/iGenVar_S/g' {output.res_S}
                sed -i 's/S1L1/iGenVar_SL1/g' {output.res_SL1}
                sed -i 's/S1L2/iGenVar_SL2/g' {output.res_SL2}
                sed -i 's/S1L3/iGenVar_SL3/g' {output.res_SL3}
            """)
        else: # wildcards.dataset == 'Illumina_Mate_Pair'
            shell("""
            cp -r results/caller_comparison_iGenVar_only/eval/S2/no_DUP_and_INV.min_qual_{wildcards.min_qual} \
                results/caller_comparison_short_read/Illumina_Mate_Pair/eval/iGenVar_S/
            """)
            shell("""
            cp -r results/caller_comparison_iGenVar_only/eval/S2L1/no_DUP_and_INV.min_qual_{wildcards.min_qual} \
                results/caller_comparison_short_read/Illumina_Mate_Pair/eval/iGenVar_SL1/
            """)
            shell("""
            cp -r results/caller_comparison_iGenVar_only/eval/S2L2/no_DUP_and_INV.min_qual_{wildcards.min_qual} \
                results/caller_comparison_short_read/Illumina_Mate_Pair/eval/iGenVar_SL2/
            """)
            shell("""
            cp -r results/caller_comparison_iGenVar_only/eval/S2L3/no_DUP_and_INV.min_qual_{wildcards.min_qual} \
                results/caller_comparison_short_read/Illumina_Mate_Pair/eval/iGenVar_SL3/
            """)
            shell("""
                sed -i 's/S2/iGenVar_S/g' {output.res_S}
                sed -i 's/S2L1/iGenVar_SL1/g' {output.res_SL1}
                sed -i 's/S2L2/iGenVar_SL2/g' {output.res_SL2}
                sed -i 's/S2L3/iGenVar_SL3/g' {output.res_SL3}
            """)

# Vaquita (no threading possible)
rule run_Vaquita:
    output:
        vcf = "results/caller_comparison_short_read/{dataset}/Vaquita/variants_without_contigs.vcf"
    log:
        "logs/caller_comparison_short_read/Vaquita_output.{dataset}.log"
    run:
        if wildcards.dataset == 'Illumina_Paired_End':
            short_bam = config["short_read_bam"]["s1"],
            genome = config["reference_fa"]["Illumina_Paired_End"]
        else: # wildcards.dataset == 'Illumina_Mate_Pair'
            short_bam = config["short_read_bam"]["s2"],
            genome = config["reference_fa"]["Illumina_Mate_Pair"]
        shell("""
            /usr/bin/time -v ./build/vaquita/bin/vaquita call --referenceGenome {genome} --cutoff 1 \
                --minSVSize {min_var_length} {short_bam} > {output.vcf} 2> {log}
        """)
        # Defaults:
        #     -v, --minVote INTEGER
        #         Minimum number of evidence types(=vote) that support SVs for rescue. -1: Supported by all evidence types.
        #         Default: -1.
        #     -q, --minMapQual INTEGER
        #         Mapping quaility cutoff. Default: 20.
        #     -a, --adjTol INTEGER
        #         Positional adjacency in nucleotide resolution. Default: 50.
        # Split-read evidence:
        #     -ss, --maxSplit INTEGER
        #         Maximum number of segments in a single read. Default: 2.
        #     -so, --maxOverlap INTEGER
        #         Maximum allowed overlaps between segements. Default: 20.
        #     -se, --minSplitReadSupport DOUBLE
        #         SVs supported by >= se get a vote. Default: 1.
        # Read-pair evidence:
        #     -ps, --pairedEndSearchSize INTEGER
        #         Size of breakpoint candidate regions. Default: 500.
        #     -pi, --abInsParam DOUBLE
        #         Discordant insertion size: median +/- (MAD * pi) Default: 9.0.
        #     -pd, --depthOutlier DOUBLE
        #         Depth outlier: {Q3 + (IQR * pd)} Default: 1.0.
        #     -pe, --minPairSupport DOUBLE
        #         SVs supported by >= pe get a vote. Default: 1.
        # Soft-clipped evidence:
        #     -cs, --minClippedSeqSize INTEGER
        #         Minimum size of clipped sequence to be considered. Default: 20.
        #     -ce, --clippedSeqErrorRate DOUBLE
        #         Maximum edit distance: floor{length of clipped sequence * (1 - ce)}. Default: 0.1.
        # Read-depth evidence:
        #     -rs, --samplingNum INTEGER
        #         Number of random sample to estimate the background distribution(Q3, IQR, ..) of read-depth evidence.
        #         Default: 100000.
        #     -rw, --readDepthWindowSize INTEGER
        #         Window size to caclulate average read-depth around breakpoints. Default: 20.
        #     --use-re-for-bs
        #         Use RE for balanced SVs(eg. inverison).
        #     -re, --reThreshold DOUBLE
        #         SVs satisfy read-depth evidence >= {Q3 + (IQR * re)} get a vote. Default: 1.0.

# add missing contig lines to header (copied from iGenVar)
rule fix_Vaquita:
    input:
        vcf = "results/caller_comparison_short_read/{dataset}/Vaquita/variants_without_contigs.vcf"
    output:
        vcf_1 = "results/caller_comparison_short_read/{dataset}/Vaquita/variants_without_fileformat.vcf",
        vcf_2 = "results/caller_comparison_short_read/{dataset}/Vaquita/variants.vcf"
    run:
        if wildcards.dataset == 'Illumina_Paired_End':
            igenvar_vcf = "results/caller_comparison_iGenVar_only/S1/variants.vcf"
        else: # wildcards.dataset == 'Illumina_Mate_Pair'
            igenvar_vcf = "results/caller_comparison_iGenVar_only/S2/variants.vcf"
        shell("""
            fileformat=$(head -n 1 {input.vcf}) && \
            less {igenvar_vcf} | grep contig | cat - {input.vcf} > {output.vcf_1} && \
            echo $fileformat | cat - {output.vcf_1} > {output.vcf_2}
        """)
        # without the 'chr' prefix:
        if wildcards.dataset == 'Illumina_Paired_End':
            shell("sed -i -e 's/ID=chr/ID=/g' {output.vcf_2}")

# Vaquita-LR
# We have only results for S1, S1L1, S1L2
rule copy_Vaquita_LR_results:
    output:
        res_S = "results/caller_comparison_short_read/{dataset}/eval/VaquitaLR_S/DUP_as_INS.min_qual_{min_qual}/pr_rec.txt",
        res_SL1 = "results/caller_comparison_short_read/{dataset}/eval/VaquitaLR_SL1/DUP_as_INS.min_qual_{min_qual}/pr_rec.txt",
        res_SL2 = "results/caller_comparison_short_read/{dataset}/eval/VaquitaLR_SL2/DUP_as_INS.min_qual_{min_qual}/pr_rec.txt",
        res_SL3 = "results/caller_comparison_short_read/{dataset}/eval/VaquitaLR_SL3/DUP_as_INS.min_qual_{min_qual}/pr_rec.txt"
    threads: 1
    run:
        if wildcards.dataset == 'Illumina_Paired_End':
            shell("""
                cp -r results/caller_comparison_vaquita_lr/eval/S1/DUP_as_INS.min_qual_{wildcards.min_qual} \
                    results/caller_comparison_short_read/{wildcards.dataset}/eval/VaquitaLR_S/
            """)
            shell("""
                cp -r results/caller_comparison_vaquita_lr/eval/S1L1/DUP_as_INS.min_qual_{wildcards.min_qual} \
                    results/caller_comparison_short_read/{wildcards.dataset}/eval/VaquitaLR_SL1/
            """)
            shell("""
                cp -r results/caller_comparison_vaquita_lr/eval/S1L2/DUP_as_INS.min_qual_{wildcards.min_qual} \
                    results/caller_comparison_short_read/{wildcards.dataset}/eval/VaquitaLR_SL2/
            """)
            # As Vaquita LR S1L3 does not exist, we create empty files.
            shell("""
                # cp -r results/caller_comparison_vaquita_lr/eval/S1L3/DUP_as_INS.min_qual_{wildcards.min_qual} \
                #     results/caller_comparison_short_read/{wildcards.dataset}/eval/VaquitaLR_SL3/
                echo 'VaquitaLR_SL3\t{wildcards.min_qual}\tprecision\t0\nVaquitaLR_SL3\t{wildcards.min_qual}\trecall\t0' > {output.res_SL3}
            """)
            shell("""
                sed -i 's/S1/VaquitaLR_S/g' {output.res_S}
                sed -i 's/S1L1/VaquitaLR_SL1/g' {output.res_SL1}
                sed -i 's/S1L2/VaquitaLR_SL2/g' {output.res_SL2}
                sed -i 's/S1L3/VaquitaLR_SL3/g' {output.res_SL3}
            """)
        else: # wildcards.dataset == 'Illumina_Mate_Pair'
            # As Vaquita LR S2 and all combinations not exist, we create empty files.
            shell("""
                # cp -r results/caller_comparison_vaquita_lr/eval/S2/DUP_as_INS.min_qual_{wildcards.min_qual} \
                #     results/caller_comparison_short_read/{wildcards.dataset}/eval/VaquitaLR_S/
                echo 'VaquitaLR_S\t{wildcards.min_qual}\tprecision\t0\nVaquitaLR_S\t{wildcards.min_qual}\trecall\t0' > {output.res_S}
            """)
            shell("""
                # cp -r results/caller_comparison_vaquita_lr/eval/S2L1/DUP_as_INS.min_qual_{wildcards.min_qual} \
                #     results/caller_comparison_short_read/{wildcards.dataset}/eval/VaquitaLR_SL1/
                echo 'VaquitaLR_SL1\t{wildcards.min_qual}\tprecision\t0\nVaquitaLR_SL1\t{wildcards.min_qual}\trecall\t0' > {output.res_SL1}
            """)
            shell("""
                # cp -r results/caller_comparison_vaquita_lr/eval/S2L2/DUP_as_INS.min_qual_{wildcards.min_qual} \
                #     results/caller_comparison_short_read/{wildcards.dataset}/eval/VaquitaLR_SL2/
                echo 'VaquitaLR_SL2\t{wildcards.min_qual}\tprecision\t0\nVaquitaLR_SL2\t{wildcards.min_qual}\trecall\t0' > {output.res_SL2}
            """)
            shell("""
                # cp -r results/caller_comparison_vaquita_lr/eval/S2L3/DUP_as_INS.min_qual_{wildcards.min_qual} \
                #     results/caller_comparison_short_read/{wildcards.dataset}/eval/VaquitaLR_SL3/
                echo 'VaquitaLR_SL3\t{wildcards.min_qual}\tprecision\t0\nVaquitaLR_SL3\t{wildcards.min_qual}\trecall\t0' > {output.res_SL3}
            """)
            shell("""
                sed -i 's/S2/VaquitaLR_S/g' {output.res_S}
                sed -i 's/S2L1/VaquitaLR_SL1/g' {output.res_SL1}
                sed -i 's/S2L2/VaquitaLR_SL2/g' {output.res_SL2}
                sed -i 's/S2L3/VaquitaLR_SL3/g' {output.res_SL3}
            """)

# Delly2
rule run_Delly2:
    output:
        bcf = "results/caller_comparison_short_read/{dataset}/Delly2/variants.bcf"
    log:
        "logs/caller_comparison_short_read/Delly2_output.{dataset}.log"
    threads: 8
    run:
        if wildcards.dataset == 'Illumina_Paired_End':
            short_bam = config["short_read_bam"]["s1"],
            genome = config["reference_fa"]["Illumina_Paired_End"]
        else: # wildcards.dataset == 'Illumina_Mate_Pair'
            short_bam = config["short_read_bam"]["s2"],
            genome = config["reference_fa"]["Illumina_Mate_Pair"]
        shell("""
            export OMP_NUM_THREADS={threads} && \
            /usr/bin/time -v \
            delly call --outfile {output.bcf} --genome {genome} --map-qual 1 {short_bam} &>> {log}
        """)
        # -t [ --type ] arg (=DEL)          SV type (DEL, DUP, INV, TRA, INS)
        # -s [ --mad-cutoff ] arg (=9)      insert size cutoff, median+s*MAD (deletions only)
        # -n [ --noindels ]                 no small InDel calling
        # Genotyping options:
        # -v [ --vcffile ] arg              input VCF/BCF file for re-genotyping
        # -u [ --geno-qual ] arg (=5)       min. mapping quality for genotyping

# GRIDSS
rule run_GRIDSS:
    output:
        vcf = "results/caller_comparison_short_read/{dataset}/GRIDSS/variants.vcf"
    log:
        "logs/caller_comparison_short_read/GRIDSS_output.{dataset}.log"
    threads: 8
    params:
        workingdir = "results/caller_comparison_short_read/{dataset}/GRIDSS/",
        s1 = config["short_read_bam"]["s1"],
        s2 = config["short_read_bam"]["s2"],
        g1 = config["reference_fa"]["Illumina_Paired_End"],
        g2 = config["reference_fa"]["Illumina_Mate_Pair"]
        # blacklist = config["blacklist"]
    conda:
        "../../../envs/gridss.yaml"
    shell:
        """
            if [[ "{wildcards.dataset}" == "Illumina_Paired_End" ]]
            then
                /usr/bin/time -v gridss --reference {params.g1} --output {output.vcf} --threads {threads} \
                    --workingdir {params.workingdir} {params.s1} --jvmheap 100g &>> {log}
            else # dataset == 'Illumina_Mate_Pair'
                /usr/bin/time -v gridss --reference {params.g2} --output {output.vcf} --threads {threads} \
                    --workingdir {params.workingdir} {params.s2} --jvmheap 100g &>> {log}
            fi
        """
    #               --workingdir {params.workingdir} --blacklist {params.blacklist} {short_bam} --jvmheap 100g &>> {log}
    # If your input files are aligned with bwa mem or another aligner that reports split read alignments using the SA tag, then runtime can be reduced by specifying --skipsoftcliprealignment.
    # Defaults:
    # -a/--assembly: location of the GRIDSS assembly BAM. This file will be
    #     created by GRIDSS.
    # -j/--jar: location of GRIDSS jar
    # -l/--labels: comma separated labels to use in the output VCF for the input
    #     files. Supporting read counts for input files with the same label are
    #     aggregated (useful for multiple sequencing runs of the same sample).
    #     Labels default to input filenames, unless a single read group with a
    #     non-empty sample name exists in which case the read group sample name
    #     is used (which can be disabled by "useReadGroupSampleNameCategoryLabel=false"
    #     in the configuration file). If labels are specified, they must be
    #     specified for all input files.
    # --externalaligner: use the system version of bwa instead of the in-process
    #     version packaged with GRIDSS (default)
    # --internalaligner: use the in-process version of bwa instead of system
    #     version. Faster but alignment results can change between runs.
    # --otherjvmheap: size of JVM heap for everything else. Useful to prevent
    #     java out of memory errors when using large (>4Gb) reference genomes.
    #     Note that some parts of assembly and variant calling use this heap
    #     size. (Default: 4g)
    # --skipsoftcliprealignment: [EXPERIMENTAL] skip soft clip realignment.
    #     Reduces runtime for aligners that report split read alignments.
    # --maxcoverage: maximum coverage. Regions with coverage in excess of this
    #     are ignored. (Default: 50000)
    # --picardoptions: additional standard Picard command line options. Useful
    #     options include VALIDATION_STRINGENCY=LENIENT and COMPRESSION_LEVEL=0.
    #     https://broadinstitute.github.io/picard/command-line-overview.html
    # --useproperpair: use SAM 'proper pair' flag to determine whether a read
    #     pair is discordant. Default: use library fragment size distribution to
    #     determine read pair concordance.
    # --concordantreadpairdistribution: portion of 6 sigma read pairs distribution
    #     considered concordantly mapped. (Default: 0.995)
    # --nojni: do not use JNI native code acceleration libraries JNI libraries:
    #     snappy, GKL, ssw, bwa
    # --jobindex: zero-based assembly job index. Only required when performing
    #     parallel assembly across multiple processes.
    # --jobnodes: total number of assembly jobs. Only required when performing
    #     parallel assembly across multiple processes.
