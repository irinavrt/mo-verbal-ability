library(tidyverse)

# list of 98 moral issues from GSS with questions used in Vartanova et al., 2020 
gss_items <- read_csv("data/gss-items-98v.csv")

# mtruk workers demographics
workers <- read_rds("data/selected-workers-for-new-argument-study-version3-from2000.rds")
# time_trends <- read_rds("data/time-trends-98v.rds")

# mturk data, one file for each group 
amt <- as_tibble(expand.grid(polviews = c("liberal", "conservative"), verb_ab = c("high", "low")))

amt <- amt %>% 
  mutate(filename = str_c("data/mturk-data/", polviews, "-", verb_ab, ".csv"),
         data = map(filename, read_csv, 
                    col_types = cols(
                      .default = col_character(),
                      MaxAssignments = col_double(),
                      AssignmentDurationInSeconds = col_double(),
                      AutoApprovalDelayInSeconds = col_double(),
                      NumberOfSimilarHITs = col_logical(),
                      LifetimeInSeconds = col_logical(),
                      RejectionTime = col_logical(),
                      RequesterFeedback = col_logical(),
                      WorkTimeInSeconds = col_double(),
                      Answer.answer = col_double(),
                      Answer.heard = col_double(),
                      Answer.opinionbefore = col_double(),
                      Answer.opinionnow = col_double()
                    ))) %>% 
  unnest(data)

amt <- amt %>% 
  left_join(gss_items, by = c("Input.question" = "question")) 

amt <- amt %>%
  select(issue,
         polviews,
         verb_ab,
         WorkerId,
         quest = Input.question,
         answer = Answer.answer,
         arg = Answer.arg,
         counter_arg = Answer.counterarg,
         exposure = Answer.heard,
         belief_before = Answer.opinionbefore,
         belief_now = Answer.opinionnow) 


# clean arguments data

full_arguments <- amt %>% 
  separate(arg, str_c("arg.", 1:9)) %>% 
  separate(counter_arg, str_c("counter_arg.", 1:9)) %>% 
  gather(order, mf, arg.1:counter_arg.9) %>% 
  drop_na(mf) %>% 
  separate(order, c("type", "order"), sep = "\\.") %>% 
  select(-order) %>% 
  mutate(mf = factor(mf, labels = c("harm", 
                                    "fair", 
                                    "ingr", 
                                    "auth", 
                                    "pure", 
                                    "lib", 
                                    "viol",
                                    "govern",
                                    "other" )),
         value = 1) %>% 
  spread(mf, value, fill = 0) %>% 
  gather(mf, value, harm:other) %>% 
  spread(type, value) %>% 
  mutate(pro = ifelse(answer == 1, arg, counter_arg),
         against = ifelse(answer == 0, arg, counter_arg)) %>% 
  select(-arg, -counter_arg) %>% 
  gather(type, value, pro, against) %>% 
  mutate(agree_position = ifelse(type == "pro", answer, 1 - answer))

full_arguments <- full_arguments %>% 
  mutate(position = str_c(issue, type, sep = "_"))

full_arguments <- full_arguments %>% 
  left_join(workers %>% 
              select(WorkerId,
                     group, aff, strength, polviews_cat,
                     round, age, sex, edu,
                     wordsum, wordsum_cat,
                     sci_knowledge, sci_kn_cat, 
                     oth_att, oth_att_cat))

write_rds(full_arguments, "data/full-arguments-data.rds")


# calculate mf measures ---------------------------------------------------

# filter data for only universal arguments, aggregate by position, 
# and calculate advantage of pro position for each issue

mf_data <- full_arguments %>%
  filter(mf %in% c("harm", "fair", "lib", "viol")) %>% 
  group_by(issue, type) %>% 
  summarise(hfvl = mean(value, na.rm = TRUE)) %>% 
  spread(type, hfvl) %>% 
  transmute(hfvl_advantage = pro - against) %>% 
  ungroup()

write_rds(mf_data, "data/mf-advantage.rds")
