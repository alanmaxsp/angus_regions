## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(echo = TRUE)
library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(purrr)
library(magrittr)
library(glue)

source(here::here("source_functions/sample_until.R"))
source(here::here("source_functions/three_gen.R"))
source(here::here("source_functions/ped.R"))
source(here::here("source_functions/write_tworegion_data.R"))
source(here::here("source_functions/region_key.R"))

## -----------------------------------------------------------------------------
iter <- as.character(commandArgs(trailingOnly = TRUE)[1])

sample_limit <- as.numeric(commandArgs(trailingOnly = TRUE)[2])

## -----------------------------------------------------------------------------
ped <-
  pull_ped(refresh = FALSE)

## -----------------------------------------------------------------------------
animal_regions <-
  read_rds(here::here("data/derived_data/import_regions/animal_regions.rds"))
  
## --------------------------------------------------------------------------

# List of dams with records in region 3 and another region

multi_dam <-
  animal_regions %>%
  group_by(dam_reg, region) %>%
  tally() %>%
   ungroup() %>%
  group_by(dam_reg) %>%
  filter(n_distinct(region) > 1) %>%
  ungroup() %>%
  tidyr::pivot_wider(id_cols = dam_reg,
                     names_from = region,
                     values_from = n) %>%
  filter(!is.na(`3`)) %>%
  pull(dam_reg)

# Exclude their calves to get around MPE covariance issues

animal_regions %<>%
  filter(!dam_reg %in% multi_dam) %>%
  # Re-filter for contemporary group size
  group_by(cg_new) %>%
  filter(n() >= 5) %>%
  ungroup() %>% 
  mutate(region = as.character(region))

# "Master" High Plains zips

master_zips <-
  animal_regions %>% 
  filter(region == 3) %>% 
  sample_until(limit = sample_limit,
               tolerance = 500,
               var = zip,
               id_var = unique(.$region)) %>% 
  mutate(region = as.character(id)) %>% 
  select(-id)

## -----------------------------------------------------------------------------
keep_zips <-
  animal_regions %>%
  filter(!zip %in% master_zips$zip) %>% 
  group_by(region) %>%
  group_map(~ sample_until(.x,
                           # Changed to 50,000 on 9/25/20
                           limit = sample_limit,
                           tolerance = 500,
                           var = zip,
                           id_var = unique(.$region)) %>%
              ungroup(),
            keep = TRUE) %>%
  reduce(bind_rows) %>%
  rename(region = id) %>% 
  mutate(region = if_else(region == 3, "3alt", as.character(region)))

# Bind "master" High Plains zips

keep_zips %<>% 
  bind_rows(master_zips)
  
## -----------------------------------------------------------------------------
iter_data <-
  keep_zips %>% 
  left_join(animal_regions %>% 
              select(-region),
            by = "zip")

## -----------------------------------------------------------------------------
c("1", "2", "3alt", "5", "7", "8", "9") %>%
  purrr::map(~ write_tworegion_data(iter = iter,
                                    comparison_region = .x,
                                    df = iter_data))


## -----------------------------------------------------------------------------
c("1", "2", "3alt", "5", "7", "8", "9") %>%
  purrr::map(~ iter_data %>%
               filter(region %in% c("3", .x)) %>%
               select(full_reg, sire_reg, dam_reg) %>%
               three_gen(full_ped = ped) %>%
               write_delim(here::here(glue("data/derived_data/gibbs_varcomp/iter{iter}/3v{.x}/ped.txt")),
                           delim = " ",
                           col_names = FALSE))

## -----------------------------------------------------------------------------
iter_data %>%
  group_by(region, zip) %>%
  summarise(n_records = n(),
            mean_weight = mean(weight)) %>%
  ungroup() %>%
  write_csv(here::here(glue::glue("data/derived_data/gibbs_varcomp/iter{iter}/gibbs_varcomp.data_summary.iter{iter}.csv")))
