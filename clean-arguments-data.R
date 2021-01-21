library(tidyverse)

# list of 98 moral issues from GSS with questions used in Vartanova et al., 2020 
gss_items <- read_csv("data/gss-items-98v.csv")

amt <- read_csv("data/raw-argument-data.csv")
# mtruk workers demographics
workers <- read_csv("data/workers-demo.csv")


full_arguments <- amt %>% 
  separate(arg, str_c("arg.", 1:9), fill = "right") %>% 
  separate(counter_arg, str_c("counter_arg.", 1:9), fill = "right") %>% 
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

full_arguments <- left_join(full_arguments, workers)

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

mf_data <-  mf_data %>% 
  left_join(
    full_arguments %>%
      filter(mf %in% c("harm", "fair", "lib", "viol")) %>% 
      group_by(verb_ab, issue, type) %>% 
      summarise(hfvl = mean(value, na.rm = TRUE)) %>% 
      spread(type, hfvl) %>% 
      transmute(hfvl_advantage = pro - against) %>% 
      spread(verb_ab, hfvl_advantage) %>% 
      rename(hfvl_adv_low = low, hfvl_adv_high = high) %>% 
      ungroup()
)

write_rds(mf_data, "data/mf-advantage.rds")
