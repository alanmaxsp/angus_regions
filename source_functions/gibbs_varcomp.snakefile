# nohup snakemake -s source_functions/gibbs_varcomp.snakefile --directory /home/agiintern/angus_regions --rerun-incomplete --latency-wait 90 --resources load=100 -j 20 --config &> log/snakemake_log/gibbs_varcomp/210203.gibbs_varcomp.log &

import os

# Make log directories if they don't exist
os.makedirs("/home/agiintern/angus_regions/log/rule_log/gibbs_varcomp", exist_ok = True)
os.makedirs("/home/agiintern/angus_regions/log/rule_log/gibbs_varcomp/sample", exist_ok = True)

os.makedirs("/home/agiintern/angus_regions/log/psrecord/gibbs_varcomp", exist_ok = True)
os.makedirs("/home/agiintern/angus_regions/log/psrecord/gibbs_varcomp/gibbs", exist_ok = True)

configfile: "source_functions/config/gibbs_varcomp.config.yaml"

rule all:
    input:
     expand("data/derived_data/gibbs_varcomp/iter{iter}/{dataset}/{file}", iter = config['iter'], dataset = config['dataset'], file = ["postout", "postmean"])

# Create sample datasets
rule sample:
    resources:
        load = 50
    input:
        script = "source_functions/setup.gibbs_varcomp.R",
        animal_regions = "data/derived_data/import_regions/animal_regions.rds",
        ped = "data/derived_data/import_regions/ped.rds"
    params:
        iter = "{iter}",
        sample_limit = config['sample_limit'],
        rule_log = "log/rule_log/gibbs_varcomp/sample/sample.iter{iter}.log"
    output:
        datafile = expand("data/derived_data/gibbs_varcomp/iter{{iter}}/{dataset}/data.txt", dataset = config['dataset']),
        pedfile = expand("data/derived_data/gibbs_varcomp/iter{{iter}}/{dataset}/ped.txt", dataset = config['dataset']),
        summary = "data/derived_data/gibbs_varcomp/iter{iter}/gibbs_varcomp.data_summary.iter{iter}.csv"
    shell:
        "Rscript --vanilla {input.script} {params.iter} {params.sample_limit} &> {params.rule_log}"

rule copy_par:
    input:
        par = "source_functions/par/gibbs_varcomp.par",
    output:
        par = "data/derived_data/gibbs_varcomp/iter{iter}/{dataset}/gibbs_varcomp.par"
    shell:
        "cp {input.par} {output.par}"

rule renf90:
    resources:
        load = 20
    input:
        par = "data/derived_data/gibbs_varcomp/iter{iter}/{dataset}/gibbs_varcomp.par",
        datafile = "data/derived_data/gibbs_varcomp/iter{iter}/{dataset}/data.txt",
        pedfile = "data/derived_data/gibbs_varcomp/iter{iter}/{dataset}/ped.txt"
    params:
        renumf90_path = config['renumf90_path'],
        directory = "data/derived_data/gibbs_varcomp/iter{iter}/{dataset}",
        par = "gibbs_varcomp.par",
        renum_out = "renf90.iter{iter}.{dataset}.out"
    output:
        renum_par = "data/derived_data/gibbs_varcomp/iter{iter}/{dataset}/renf90.par"
    shell:
        """
        cd {params.directory}
        {params.renumf90_path} {params.par} &> {params.renum_out}
        """

rule gibbs:
    resources:
        load = 5
    input:
        renum_par = "data/derived_data/gibbs_varcomp/iter{iter}/{dataset}/renf90.par"
    params:
        gibbs_path = config['gibbs_path'],
        directory = "data/derived_data/gibbs_varcomp/iter{iter}/{dataset}",
        rounds = config['rounds'],
        burnin = config['burnin'],
        thin = config['thin'],
        gibbs_out = "gibbs.iter{iter}.{dataset}.out",
        psrecord = "/home/agiintern/angus_regions/log/psrecord/gibbs_varcomp/gibbs/gibbs.iter{iter}.{dataset}.log"
    output:
        dummy = "data/derived_data/gibbs_varcomp/iter{iter}/{dataset}/gibbs.iter{iter}.{dataset}.out"
    shell:
        """
        cd {params.directory}
        psrecord "echo -e 'renf90.par \\n {params.rounds} {params.burnin} \\n {params.thin}' | {params.gibbs_path} &> {params.gibbs_out}" --log {params.psrecord} --include-children --interval 5
        cp last_solutions last_solutions_backup
        echo "done" dummy.txt
        """

rule post_gibbs:
    resources:
        load = 10
    input:
        dummy = "data/derived_data/gibbs_varcomp/iter{iter}/{dataset}/gibbs.iter{iter}.{dataset}.out"
    params:
        directory = "data/derived_data/gibbs_varcomp/iter{iter}/{dataset}",
    output:
        postout = "data/derived_data/gibbs_varcomp/iter{iter}/{dataset}/postout",
        postmean = "data/derived_data/gibbs_varcomp/iter{iter}/{dataset}/postmean"
    # All integer arguments need to be strings in yaml config file in order to run
    run:
        import pexpect
        child = pexpect.spawn(config['post_gibbs_path'] + ' renf90.par', cwd = params.directory)
        child.expect('Burn-in?')
        child.sendline(config['post_gibbs_burnin'])
        child.expect('Give n to read')
        child.sendline(config['thin'])
        child.expect('Choose a graph for samples')
        child.sendline('0')