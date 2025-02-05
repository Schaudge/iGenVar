library(tidyverse)

# Rscript --vanilla scripts/plot_all.R {input} {parameter_name} {output}

args = commandArgs(trailingOnly=TRUE)

bam_name <- args[2]
parameter_name = args[3]
benchmark_title = c("Parameter Benchmarks - ", parameter_name)

if (parameter_name == "min_var_length") {
  parameter_values = c(10,30,50,75,100)
} else if (parameter_name == "max_var_length") {
  parameter_values = c(1000,5000,10000,100000)
} else if (parameter_name == "max_tol_inserted_length") {
  parameter_values = c(10,50,100)
} else if (parameter_name == "max_tol_deleted_length") {
  parameter_values = c(10,50,100)
} else if (parameter_name == "max_overlap") {
  parameter_values = c(10,50,100)
} else if (parameter_name == "partition_max_distance") {
  parameter_values = c(10,25,50,100,1000)
} else {                    # hierarchical_clustering_cutoff
  parameter_values = c(0.1,0.2,0.3,0.4)
}

res <- read_tsv(args[1], col_names = c(parameter_name, "min_qual", "metric", "value"))
res[[parameter_name]] = factor(res[[parameter_name]], levels=parameter_values, labels=as.character(parameter_values))

res %>%
    filter(metric %in% c("recall", "precision")) %>%
    pivot_wider(names_from=metric, values_from=value) %>%
    filter(recall!=0 | precision!=0) %>%
    mutate(precision = 100*precision, recall = 100*recall) %>%
    ggplot(aes(recall, precision, color = get(parameter_name), pch = get(parameter_name))) +
      geom_point(size=0.5) +
      geom_path() +
      labs(y = "Precision", x = "Recall", color = parameter_name, pch = parameter_name,
           title=benchmark_title, subtitle=bam_name) +
      lims(x=c(0,100), y=c(0,100)) +
      theme_bw() +
      theme(text = element_text(size=14), axis.text.x = element_text(size=9), axis.text.y = element_text(size=9))

ggsave(args[4], width=7, height=6)
