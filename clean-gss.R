# Raw GSS date used in this script is not provided in the repository 
# and has to be downloaded from http://gss.norc.org/get-the-data/spss

library(tidyverse)
library(haven)
#library(broom)

source("auxiliary_functions.R")

gss_full <- read_sav("data/GSS7218_R2.sav")
gss_items <- read_csv("data/gss-items-98v.csv")

# otherish_items <- c("peoptrbl", "selffrst", "selfless", "givblood", "givhmlss",
#                     "retchnge", "cutahead", "volchrty", "givchrty", "givseat",
#                     "helpaway", "carried",  "directns", "loanitem", "helphwrk",
#                     "lentto",   "talkedto", "helpjob")

gss <- gss_full %>%
  rename_all(tolower) %>% 
  select(id, year, wtssall, oversamp, sample, polviews, partyid, wordsum, degree, educ, 
         sex, age, race, class, region, finrela, relig, attend, god, reliten,
         #one_of(otherish_items),
         one_of(gss_items$issue))

gss <- gss %>% 
  mutate_at(vars(id, wtssall, oversamp, age, educ, year, polviews, wordsum), zap_labels) %>% 
  mutate_if(is.labelled, ~fct_relabel(as_factor(.), tolower)) %>% 
  mutate(birth_year = year - age,
         # rescale polviews bw -3 (conservative) and 3 (liberal),
         polviews_cont = 4 - polviews,
         polviews = cut(polviews, c(0, 3, 4, 7), 
                        labels = c("liberal", "moderate", "conservative")),
         polviews = fct_rev(polviews),
         time = (year - 1972)/10,
         wgt = wtssall*oversamp)

# recode neutral levels that are not in the middle of factor levels to NA
gss <- gss %>% 
  mutate(class = fct_recode(class, NULL = "no class"),
         homosex = fct_recode(homosex, NULL = "other"),
         racchng = fct_recode(racchng, NULL = "wdnt belong"),
         racopen = fct_recode(racopen, NULL = "neither"),
         sexeduc = fct_recode(sexeduc, NULL = "depends"),
         relig = fct_lump(relig, prop = .05),
         reliten = fct_relevel(reliten, "no religion", "not very strong", 
                               "somewhat strong", "strong")) 

#Excluding years where racial questions were asked of non-blacks only 
for(i in c("racmar","racpush", "racopen","racdin")) {
  gss[gss$year %in% 1972:1977,i] <- NA
}

gss <- gss %>% droplevels()

# recode issues to binary with 1 indicating agreement to the default position 
# if relevant, the neutral middle category is omited

gss_bin <- gss %>% 
  mutate(pornlaw = ifelse(pornlaw == "legal", 0 , 1)) %>% 
  mutate_at(gss_items$issue[gss_items$issue != "pornlaw"], dichotomize)

write_rds(gss_bin, "data/cleaned-gss.rds", compress = "gz")



