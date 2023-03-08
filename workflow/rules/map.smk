import itertools
ruleorder: map_plasmid > map_samples

LIBS = ["LDLvar", "LDLRCDS"]

REPS = {
    "LDLvar":list(range(1, 16)), #1-15
    "LDLRCDS":list(range(1, 10)) #1-9
}
# rule get_fastq_data:
#     output:
#         # R1s = expand(
#         #     ["results/raw/{wildcards.lib}/{wildcards.lib}_{rep_bin}_R1.fastq.gz"],
#         #     rep_bin = get_reps_bins(wildcards.lib)
#         # ),
#         # R2s = expand(
#         #     ["results/raw/{wildcards.lib}/{wildcards.lib}_{rep_bin}_R2.fastq.gz"],
#         #     rep_bin = get_reps_bins(wildcards.lib)
#         # ),
#         #plasimd_R1 = "results/raw/{lib}/{lib}_plasmid_R1.fastq.gz",
#         #plasmid_R2 = "results/raw/{lib}/{lib}_plasmid_R2.fastq.gz",
#         sample_list_file = 'results/raw/{lib}/sample_list.csv',
#         guide_start_seqs = "results/raw/{lib}/guide_start_seqs.txt"

rule write_guide_start_seqs_file:
    output:
        guide_start_seqs = "results/raw/{lib}/guide_start_seqs.txt"
    shell:
        "python scripts/map_collect/write_guide_start_seq.py {wildcards.lib} {output.guide_start_seqs}"

rule write_sample_list_file:
    output:
        sample_list='results/raw/{lib}/sample_list.csv'
    shell:
        "python scripts/map_collect/write_sample_list_file.py {wildcards.lib} {output.sample_list}"

rule map_plasmid:
    input:
        guide_info = 'resources/gRNA_info/{lib}_gRNA_bean.csv',
        plasmid_R1 = "results/raw/{lib}/{lib}_plasmid_R1.fastq.gz",
        plasmid_R2 = "results/raw/{lib}/{lib}_plasmid_R2.fastq.gz",
    params:
        output_dir = 'results/mapped/{lib}'
    output:
        out_h5ad = 'results/mapped/{lib}/bean_count_{lib}_plasmid.h5ad'
    run:
        shell('mkdir -p {params.output_dir}')
        shell(
            "bean-count --R1 {input.plasmid_R1} --R2 {input.plasmid_R2} -b A -f {input.guide_info} -o {params.output_dir} -r --guide-start-seq=GGAAAGGACGAAACACCG")

rule map_samples:
    input:
        guide_info = 'resources/gRNA_info/{lib}_gRNA_bean.csv',
        sample_list = 'results/raw/{lib}/sample_list.csv',# ?
        guide_start_seqs = "results/raw/{lib}/guide_start_seqs.txt",
    params:
        output_dir = 'results/mapped/{lib}/'
    output:
        out_h5ad = 'results/mapped/{lib}/bean_count_{lib}.h5ad'
    run:
        shell('mkdir -p {params.output_dir}')
        map_script = "bean-count-samples --input {input.sample_list} -b A -f {input.guide_info} -o {params.output_dir} -r -t 12 --name {wildcards.lib} --guide-start-seqs-file={input.guide_start_seqs}"
        if wildcards.lib == "LDLvar":
            map_script += " --match_target_pos"
        shell(map_script)

rule map_all:
    input:
        expand(['results/mapped/{lib}/bean_count_{lib}.h5ad'], lib=LIBS),
        expand(['results/mapped/{lib}/bean_count_plasmid_{lib}.h5ad'], lib=LIBS)

rule combine_technical_replicate:
    input:
        input_h5ad='results/mapped/{lib}/bean_count_{lib}.h5ad'
    output:
        out_h5ad='results/mapped/{lib}/bean_count_{lib}_combined.h5ad',
        #techrep_plots=expand(['results/mapped/{lib}/figs/lfc_corr_{rep}.pdf'], rep=REPS[{lib}])
    run:
        shell("python scripts/map_collect/combine_technical_replicates.py {wildcards.lib}")

