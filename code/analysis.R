# preparation -------------------------------------------------------------

# load pkgs 
pacman::p_load(tidyverse,
               scico, # for scientific color palettes
               latex2exp, # for LaTeX expressions in plots
               papaja,
               ggpubr,
               patchwork)


# load data
choices <- read_rds("data/choice_data.rds.bz2") 
cpt <- read_rds("data/cpt_estimates.rds") 
round <- read_rds("data/simulation_roundwise.rds.bz2") 
summary <- read_rds("data/simulation_summary.rds.bz2")

# plot labels

label_theta <- function(string) {
  TeX(paste("$\\theta=$", string, sep = ""))
}

label_psi <- function(string) {
  TeX(paste("$\\psi=$", string, sep = ""))
}

# propbability of high risky outcome
label_rare <- function(string) {
  TeX(paste("$\\p_{high}\\in$", string, sep = "")) 
}


# discarded trials --------------------------------------------------------

total_discarded <- choices %>% filter(c(n_s == 0 | n_r == 0)) %>% nrow() # 119971
total_discarded/nrow(choices) # 4.9% 
roundwise_discarded <- choices %>% filter(model ==  "roundwise" & c(n_s == 0 | n_r == 0)) %>% nrow() # 0
summary_discarded <- choices %>% filter(model ==  "summary" & c(n_s == 0 | n_r == 0)) %>% nrow() # 119971
summary_discarded_relative <- choices %>% filter(model ==  "summary" & threshold == "relative" & c(n_s == 0 | n_r == 0)) %>% nrow() # 0
summary_discarded_absolute <- choices %>% filter(model ==  "summary" & threshold == "absolute" & c(n_s == 0 | n_r == 0)) %>% nrow() # 119917
summary_absolute <- choices %>% filter(model ==  "summary" & threshold == "absolute") %>% nrow() # 119971
summary_discarded_absolute / summary_absolute # 20%

# accumulation trajectories -----------------------------------------------

# prepare data

## compute evidence conditional on number of sampled outcomes

### summary
summary <- summary %>% 
  mutate(psi = 1-(psi+.5)) %>% # recode psi
  filter(threshold == "relative") %>% 
  group_by(psi, threshold, theta, problem, agent) %>% # group by trial
  mutate(smp_no = row_number(), # assign sample numbers
         diff = if_else(smp_no == 1, 0, diff)) %>% 
  fill(diff) # fill missing values

####  median evidence
summary_median <- summary %>% 
  group_by(psi, threshold, theta, problem, smp_no) %>% 
  summarise(count = n(), 
            median = median(diff)) %>% 
  slice(seq_len(min(which(median <= -theta | median >= theta), n())))

### round
round <- round %>% 
  mutate(psi = 1-(psi+.5)) %>% # recode psi
  filter(threshold == "relative") %>% 
  group_by(psi, threshold, theta, problem, agent) %>% # group by trial
  mutate(smp_no = row_number(), # assign sample numbers
         diff = if_else(smp_no == 1, 0, diff)) %>% # fill missing values
  fill(diff)

#### median evidence
round_median <- round %>% 
  group_by(psi, threshold, theta, problem, smp_no) %>% 
  summarise(count = n(), 
            median = median(diff)) %>% 
  slice(seq_len(min(which(median %in% c(-theta, theta)), n())))

## find illustrative problems where option with higher EV is not the option that returns the higher outcome most of the time 
choice_problems %>% mutate(id = row_number()) %>% filter(r_ev > safe & p_r_low > p_r_high) # 7, 35 
choice_problems %>% mutate(id = row_number()) %>% filter(r_ev < safe & p_r_low < p_r_high) # 43 , 47


# plot problem 43
problem_number <- 43

## summary

summary_boundary <- 75  
summary_sub <- summary %>% 
  filter(psi %in% c((1-.9), .5, 1), theta == summary_boundary, problem == problem_number) %>% 
  mutate(diff = case_when(diff < -summary_boundary ~ -summary_boundary, 
                          diff > summary_boundary ~ summary_boundary, 
                          diff >= -summary_boundary & diff <= summary_boundary ~ diff))

summary_median_sub <- summary_median %>%  
  filter(psi %in% c((1-.9), .5, 1), theta == summary_boundary, problem == problem_number) %>%
  mutate(median = case_when(median < -summary_boundary ~ -summary_boundary, 
                            median > summary_boundary ~ summary_boundary, 
                            median >= -summary_boundary & median <= summary_boundary ~ median))

ann_risky <- data.frame(psi=(1-.9), smp_no = 40, diff=60, label="Risky Threshold \n 8.6 (19%) or 17.36 (81%)")
ann_safe <- data.frame(psi=(1-.9), smp_no = 40, diff=-60, label="Safe Threshold \n 15.70 (100%)")

summary_trajectories <- summary_sub %>% 
  ggplot(aes(x = smp_no, y = diff)) + 
  facet_wrap(~psi, nrow = 3, labeller = labeller(psi = as_labeller(label_psi, default = label_parsed)), scales = "free_x") + 
  scale_y_continuous(limits = c(-summary_boundary, summary_boundary), 
                     breaks = seq(-summary_boundary, summary_boundary, summary_boundary)) +
  labs(title = "Summary", 
       x = "Number of Sampled Outcomes",
       y = "Difference in Cumulative Sums",
       color = expression(psi),
       alpha = "Agent\nCount") +
  geom_hline(yintercept = c(-summary_boundary, 0, summary_boundary), linetype = "dashed") + 
  geom_text(data = ann_risky, label=ann_risky$label, size = 5) + 
  geom_text(data = ann_safe, label=ann_safe$label, size = 5) +
  geom_line(aes(group = agent), position = position_dodge(width = .3), size = .3, alpha = .5, color = "gray") + 
  geom_line(data = summary_median_sub, aes(y = median, alpha = count), size = 1, color = "#9c179e") +
  theme_apa(base_size = 20)

## round-wise

round_boundary <- 5
round_sub <- round %>%
  filter(psi %in% c((1-.9), .5, 1), theta == round_boundary, problem == problem_number)

round_median_sub <- round_median %>% 
  filter(psi %in% c((1-.9), .5, 1),
         theta == round_boundary, 
         problem == problem_number)

round_trajectories <- round_sub %>%
  ggplot(aes(x = smp_no, y = diff)) + 
  facet_wrap(~psi, nrow = 3, labeller = labeller(psi = as_labeller(label_psi, default = label_parsed)), scales = "free_x") + 
  scale_y_continuous(limits = c(-round_boundary, round_boundary), 
                     breaks = seq(-round_boundary, round_boundary, round_boundary)) +
  labs(title = "Roundwise", 
       x = "Number of Sampled Outcomes",
       y = "Difference in Round Wins",
       color = expression(psi),
       alpha = "Agent\nCount") +
  geom_hline(yintercept = c(-round_boundary, 0, round_boundary), linetype = "dashed") + 
  geom_line(aes(group = agent), position = position_dodge(width = .3), size = .3, alpha = .5, color = "gray") + 
  geom_line(data = round_median_sub, aes(y = median, alpha = count), size = 1, color = "#9c179e") +
  theme_apa(base_size = 20)

### merge and save plots
summary_trajectories + round_trajectories + plot_annotation(tag_levels = "A") + plot_layout(guides = "collect")
ggsave(file = "manuscript/figures/accumulation_problem_43.png", width = 14, height = 14)

# plot problem 35
problem_number <- 35

## summary
summary_boundary <- 75  
summary_sub <- summary %>% 
  filter(psi %in% c((1-.9), .5, 1), theta == summary_boundary, problem == problem_number) %>% 
  mutate(diff = case_when(diff < -summary_boundary ~ -summary_boundary, 
                          diff > summary_boundary ~ summary_boundary, 
                          diff >= -summary_boundary & diff <= summary_boundary ~ diff))

summary_median_sub <- summary_median %>%  
  filter(psi %in% c((1-.9), .5, 1), theta == summary_boundary, problem == problem_number) %>%
  mutate(median = case_when(median < -summary_boundary ~ -summary_boundary, 
                            median > summary_boundary ~ summary_boundary, 
                            median >= -summary_boundary & median <= summary_boundary ~ median))

ann_risky <- data.frame(psi=(1-.9), smp_no = 50, diff=60, label="Risky Threshold \n 10.44 (84%) or 12.33 (16%)")
ann_safe <- data.frame(psi=(1-.9), smp_no = 50, diff=-60, label="Safe Threshold \n 10.51 (100%)")

summary_trajectories <- summary_sub %>% 
  ggplot(aes(x = smp_no, y = diff)) + 
  facet_wrap(~psi, nrow = 3, labeller = labeller(psi = as_labeller(label_psi, default = label_parsed)), scales = "free_x") + 
  scale_y_continuous(limits = c(-summary_boundary, summary_boundary), 
                     breaks = seq(-summary_boundary, summary_boundary, summary_boundary)) +
  labs(title = "Summary", 
       x = "Number of Sampled Outcomes",
       y = "Difference in Cumulative Sums",
       color = expression(psi),
       alpha = "Agent\nCount") +
  geom_hline(yintercept = c(-summary_boundary, 0, summary_boundary), linetype = "dashed") + 
  geom_text(data = ann_risky, label=ann_risky$label, size = 5) + 
  geom_text(data = ann_safe, label=ann_safe$label, size = 5) +
  geom_line(aes(group = agent), position = position_dodge(width = .3), size = .3, alpha = .5, color = "gray") + 
  geom_line(data = summary_median_sub, aes(y = median, alpha = count), size = 1, color = "#9c179e") +
  theme_apa(base_size = 20)

## round-wise
round_boundary <- 5
round_sub <- round %>%
  filter(psi %in% c((1-.9), .5, 1),
         theta == round_boundary, 
         problem == problem_number)

round_median_sub <- round_median %>% 
  filter(psi %in% c((1-.9), .5, 1),
         theta == round_boundary, 
         problem == problem_number)

round_trajectories <- round_sub %>%
  ggplot(aes(x = smp_no, y = diff)) + 
  facet_wrap(~psi, nrow = 3, labeller = labeller(psi = as_labeller(label_psi, default = label_parsed)), scales = "free_x") + 
  scale_y_continuous(limits = c(-round_boundary, round_boundary), 
                     breaks = seq(-round_boundary, round_boundary, round_boundary)) +
  labs(title = "Roundwise", 
       x = "Number of Sampled Outcomes",
       y = "Difference in Round Wins",
       color = expression(psi),
       alpha = "Agent\nCount") +
  geom_hline(yintercept = c(-round_boundary, 0, round_boundary), linetype = "dashed") + 
  geom_line(aes(group = agent), position = position_dodge(width = .3), size = .3, alpha = .5, color = "gray") + 
  geom_line(data = round_median_sub, aes(y = median, alpha = count), size = 1, color = "#9c179e") +
  theme_apa(base_size = 20)

### merge and save plots
summary_trajectories + round_trajectories + plot_annotation(tag_levels = "A") + plot_layout(guides = "collect")
ggsave(file = "manuscript/figures/accumulation_problem_35.png", width = 14, height = 14)

# maximization rates ------------------------------------------------------

# compute maximization rates

## sampled average
rates_EV_exp <- choices %>%
  filter(!c(n_s == 0 | n_r == 0)) %>% # remove choices where an option was not attended 
  mutate(norm = case_when(mean_r/safe > 1 ~ "r", 
                          mean_r/safe < 1 ~ "s")) %>% # determine option with higher sampled mean 
  filter(!is.na(norm)) %>% # drop options without normative choice 
  mutate(max = ifelse(norm == choice, 1, 0)) %>% 
  group_by(model, psi, threshold, theta, max) %>% 
  summarise(n = n()) %>% 
  mutate(rate = round(n/sum(n), 2)) %>% 
  ungroup() %>%
  filter(!(max == 0))

## expected values
rates_EV <- choices %>%
  filter(!c(n_s == 0 | n_r == 0)) %>% # remove choices where an option was not attended 
  mutate(norm = case_when(r_ev/safe > 1 ~ "r", 
                          r_ev/safe < 1 ~ "s")) %>% # determine option with higher sampled mean 
  filter(!is.na(norm)) %>% # drop options without normative choice 
  mutate(max = ifelse(norm == choice, 1, 0)) %>% 
  group_by(model, psi, threshold, theta, max) %>% 
  summarise(n = n()) %>% 
  mutate(rate = round(n/sum(n), 2)) %>% 
  ungroup() %>%
  filter(!(max == 0))

# plot data 

## sampled average

### summary
max_EV_exp_summary <- rates_EV_exp %>%
  filter(model == "summary" & threshold == "relative") %>% 
  # filter(psi > .9 | psi == .5 | psi == (1-.9)) %>% 
  ggplot(aes(psi, rate, group = theta, color = theta)) +
  scale_color_scico(palette = "imola", alpha = .7) + 
  scale_x_continuous(limits = c(-.1, 1.1), breaks = seq(0, 1, length.out = 3)) +
  scale_y_continuous(limits = c(.4, 1), breaks = seq(.5, 1, length.out = 3)) +
  labs(title = "Summary Comparison", 
       x = "Switching Probability\n(Search Rule)",
       y = "% Average Maximization",
       color = "Threshold\n(Stopping Rule)") +
  geom_line(linewidth = 1) + 
  geom_point(size = 3) +
  theme_minimal(base_size = 20)

### round-wise
max_EV_exp_roundwise <- rates_EV_exp %>%
  filter(model == "roundwise" & threshold == "relative") %>% 
  # filter(psi > .9 | psi == .5 | psi == (1-.9)) %>% 
  ggplot(aes(psi, rate, group = theta, color = as.factor(theta))) +
  scale_color_scico_d(palette = "imola", alpha = .7) + 
  scale_x_continuous(limits = c(-.1, 1.1), breaks = seq(0, 1, length.out = 3)) +
  scale_y_continuous(limits = c(.4, 1), breaks = seq(.5, 1, length.out = 3)) +
  labs(title = "Roundwise Comparison", 
       x = "Switching Probability\n(Search Rule)",
       y = "% Average Maximization",
       color = "Threshold\n(Stopping Rule)") +
  geom_line(linewidth = 1) + 
  geom_point(size = 3) +
  theme_minimal(base_size = 20)

### merge plots
max_EV_exp <- ggarrange(max_EV_exp_summary, max_EV_exp_roundwise, nrow = 1)

## expected value

### summary
max_EV_summary <- rates_EV %>%
  filter(model == "summary" & threshold == "relative") %>% 
  # filter(psi > .9 | psi == .5 | psi == (1-.9)) %>% 
  ggplot(aes(psi, rate, group = theta, color = theta)) +
  scale_color_scico(palette = "imola", alpha = .7) + 
  scale_x_continuous(limits = c(-.1, 1.1), breaks = seq(0, 1, length.out = 3)) +
  scale_y_continuous(limits = c(.4, 1), breaks = seq(.5, 1, length.out = 3)) +
  labs(title = "Summary Comparison", 
       x = "Switching Probability\n(Search Rule)",
       y = "% EV Maximization",
       color = "Threshold\n(Stopping Rule)") +
  geom_line(linewidth = 1) + 
  geom_point(size = 3) +
  theme_minimal(base_size = 20)

### round-wise
max_EV_roundwise <- rates_EV %>%
  filter(model == "roundwise" & threshold == "relative") %>% 
  # filter(psi > .9 | psi == .5 | psi == (1-.9)) %>% 
  ggplot(aes(psi, rate, group = theta, color = as.factor(theta))) +
  scale_color_scico_d(palette = "imola", alpha = .7) + 
  scale_x_continuous(limits = c(-.1, 1.1), breaks = seq(0, 1, length.out = 3)) +
  scale_y_continuous(limits = c(.4, 1), breaks = seq(.5, 1, length.out = 3)) +
  labs(title = "Roundwise Comparison", 
       x = "Switching Probability\n(Search Rule)",
       y = "% EV Maximization",
       color = "Threshold\n(Stopping Rule)") +
  geom_line(linewidth = 1) + 
  geom_point(size = 3) +
  theme_minimal(base_size = 20)
max_EV <- ggarrange(max_EV_summary, max_EV_roundwise, nrow = 1)

### merge and save plots
max_EV + max_EV_exp + 
  plot_layout(ncol = 1, guides = "collect") + 
  plot_annotation(tag_levels = "A") & 
  theme(plot.tag = element_text(size = 24, face = "plain"))
ggsave(file = "manuscript/figures/maximization.png", width = 14, height = 10)

# sample size -------------------------------------------------------------

effort_summary <- choices %>% 
  filter(model == "summary", threshold == "relative") %>% 
  group_by(psi, theta) %>% 
  summarise(mean_n = mean(n_sample), 
            median_n = median(n_sample)) %>% 
  ggplot(aes(x=psi, y=median_n, group=theta, color = theta)) + 
  scale_color_scico(palette = "imola") + 
  labs(title = "Summary Comparison", 
       x = "Switching Probability\n(Search Rule)",
       y = "Median Sample Size",
       color = "Threshold\n(Stopping Rule)") +
  geom_point(size = 3) + 
  geom_line(linewidth = 1) + 
  theme_minimal(base_size = 20)

effort_roundwise <- choices %>% 
  filter(model == "roundwise", threshold == "relative") %>% 
  group_by(psi, theta) %>% 
  summarise(mean_n = mean(n_sample), 
            median_n = median(n_sample)) %>% 
  ggplot(aes(x=psi, y=median_n, group=theta, color = as.factor(theta))) + 
  scale_color_scico_d(palette = "imola") + 
  labs(title = "Roundwise Comparison", 
       x = "Switching Probability\n(Search Rule)",
       y = "Median Sample Size",
       color = "Threshold\n(Stopping Rule)") +
  geom_point(size = 3) + 
  geom_line(linewidth = 1) + 
  theme_minimal(base_size = 20)

effort_summary + effort_roundwise + plot_layout(ncol = 2) + plot_annotation(tag_levels = "A")
ggsave("manuscript/figures/sample_size.png", width = 14, height = 6)

# reward rate --------------------------------------------

# prepare data

## Maximization as a function of comparison strategies and sample size

### ground-truth
max_n <- choices %>% 
  filter(!c(n_s == 0 | n_r == 0)) %>% 
  mutate(norm = case_when(r_ev/safe > 1 ~ "r", 
                          r_ev/safe < 1 ~ "s")) %>%
  filter(!is.na(norm)) %>%
  mutate(max = ifelse(norm == choice, 1, 0)) %>% 
  group_by(model, threshold, psi, theta) %>% 
  summarise(n = n(), 
            median_n = median(n_sample) , 
            mean_n = mean(n_sample) , 
            max_prop = sum(max)/n)

### sampled 
max_n_exp <- choices %>% 
  filter(!c(n_s == 0 | n_r == 0)) %>% 
  mutate(norm = case_when(mean_r/safe > 1 ~ "r", 
                          mean_r/safe < 1 ~ "s")) %>%
  filter(!is.na(norm)) %>%
  mutate(max = ifelse(norm == choice, 1, 0)) %>% 
  group_by(model, threshold, psi, theta) %>% 
  summarise(n = n(), 
            median_n = median(n_sample) , 
            mean_n = mean(n_sample) , 
            max_prop = sum(max)/n)

## reward rate

reward_rates <- choices %>%  
  mutate(higher_EV_option = ifelse(ev_ratio > 1, "r", ifelse(ev_ratio < 1 , "s", NA)) ,
         higher_EV_exp_option = ifelse(mean_r > safe, "r", ifelse(mean_r < safe, "s", NA)) ,
         higher_EV_choice = choice == higher_EV_option , 
         higher_EV_exp_choice = choice == higher_EV_exp_option , 
         chosen_option_ev = ifelse(choice == "s", safe, ifelse(choice == "r", r_ev, NA)) ,
         chosen_option_ev_exp = ifelse(choice == "s", safe, ifelse(choice == "r", mean_r, NA)) , 
         rr_ev = chosen_option_ev/n_sample , 
         rr_ev_exp = chosen_option_ev_exp/n_sample)

# plot data

## ground-truth

### Maximization as a function of comparison strategies and sample size

#### summary
max_n_summary <- max_n %>% 
  filter(model == "summary", threshold == "relative") %>% 
  ggplot(aes(x=median_n, y=max_prop, group = psi, color = psi)) +
  scale_color_scico(palette = "tokyo", alpha = .7, end = .8) +
  labs(title = "Summary Comparison", 
       x = "Median Sample Size",
       y = "% EV Maximization",
       color = "Switching\nProbability\n(Search Rule)") +
  geom_point(size = 3) + 
  geom_line(linewidth = 1) + 
  scale_x_continuous(limits = c(0, 130), breaks = seq(0, 130, length.out = 3)) + 
  scale_y_continuous(limits = c(.5,1), breaks = seq(.5,1, length.out = 3)) +
  theme_minimal(base_size = 20)

#### roundwise
max_n_roundwise <- max_n %>% 
  filter(model == "roundwise", threshold == "relative") %>% 
  ggplot(aes(x=median_n, y=max_prop, group = psi,  color = psi)) +
  scale_color_scico(palette = "tokyo", alpha = .7, end = .8) +
  labs(title = "Roundwise Comparison", 
       x = "Median Sample Size",
       y = "% EV Maximization", 
       color = "Switching\nProbability\n(Search Rule)") +
  geom_point(size = 3) + 
  geom_line(linewidth = 1) + 
  scale_x_continuous(limits = c(0, 130), breaks = seq(0, 130, length.out = 3)) + 
  scale_y_continuous(limits = c(.5,1), breaks = seq(.5,1, length.out = 3)) +
  theme_minimal(base_size = 20)

#### merge
max_n_EV <- ggarrange(max_n_summary, max_n_roundwise, nrow = 1, common.legend = TRUE, legend = "right")

### reward rate

#### summary
rr_summary <- reward_rates %>% 
  group_by(model, psi, threshold, theta) %>% 
  summarise(mean_rr_ev = mean(rr_ev, na.rm = TRUE)) %>% 
  filter(model == "summary", threshold == "relative") %>%  
  ggplot(aes(x = psi, y = mean_rr_ev, group = theta, color = theta)) + 
  scale_color_scico(palette = "imola") + 
  geom_point(size = 3) +
  geom_line(linewidth = 1) +
  scale_shape_discrete(labels=c('EV', 'Average Outcome')) + 
  labs(title = "Summary Comparison", 
       x = "Switching Probability\n(Search Rule)", 
       y = "Mean Reward Rate",
       color = "Threshold\n(Stopping Rule)") + 
  scale_y_continuous(limits = c(0, 6), breaks = seq(0,6,length.out = 3)) + 
  theme_minimal(base_size = 20)

#### roundwise
rr_roundwise <- reward_rates %>% 
  group_by(model, psi, threshold, theta) %>% 
  summarise(mean_rr_ev = mean(rr_ev, na.rm = TRUE)) %>% 
  filter(model == "roundwise", threshold == "relative") %>%  
  ggplot(aes(x = psi, y = mean_rr_ev, group = theta, color = as.factor(theta))) + 
  scale_color_scico_d(palette = "imola") + 
  geom_point(size = 3) +
  geom_line(linewidth = 1) +
  scale_shape_discrete(labels=c('EV', 'Average Outcome')) + 
  labs(title = "Roundwise Comparison", 
       x = "Switching Probability\n(Search Rule)", 
       y = "Mean Reward Rate",
       color = "Threshold\n(Stopping Rule)") + 
  scale_y_continuous(limits = c(0, 6), breaks = seq(0,6,length.out = 3)) + 
  theme_minimal(base_size = 20)

#### merge and save
rrates <- ggarrange(rr_summary, rr_roundwise, nrow = 1)
max_n_EV + rrates + 
  plot_layout(ncol = 1, guides = "auto", ) + 
  plot_annotation(tag_levels = "A") & 
  theme(plot.tag = element_text(size = 24, face = "plain"))
ggsave(file = "manuscript/figures/efficiency.png", width = 14, height = 10)

# sampled frequencies -----------------------------------------------------

# prepare data 

## compute trial-level and round-level frequencies

### higher risky outcome
freq_high  <- round %>% 
  mutate(psi = 1-(psi+.5)) %>% # recode psi
  filter(psi %in% c((1-.9), .5, 1),
         threshold == "relative") %>% 
  group_by(psi, theta, problem, agent) %>%
  mutate(n_sample = n(), # compute trial-level n 
         n_s = sum(is.na(r)), 
         n_r = n_sample - n_s, 
         trial_freq = round(sum(if_else(r == r_high, 1, 0), na.rm = TRUE)/n_r, 2)) %>% # compute trial-level frequencies
  ungroup() %>%
  filter(!c(n_s == 0 | n_r == 0)) %>%
  group_by(psi, theta, problem, agent, round) %>% 
  mutate(n_round = n(), 
         n_round_s = sum(is.na(r)),
         n_round_r = n_round - n_round_s,
         round_freq = round(sum(if_else(r == r_high, 1, 0), na.rm = TRUE)/n_round_r, 2)) 

### lower risky outcome
freq_low  <- round %>% 
  mutate(psi = 1-(psi+.5)) %>% # recode psi
  filter(psi %in% c((1-.9), .5, 1),
         threshold == "relative") %>% 
  group_by(psi, theta, problem, agent) %>%
  mutate(n_sample = n(), # compute trial-level n 
         n_s = sum(is.na(r)), 
         n_r = n_sample - n_s, 
         trial_freq = round(sum(if_else(r == r_low, 1, 0), na.rm = TRUE)/n_r, 2)) %>% # compute trial-level frequencies
  ungroup() %>%
  filter(!c(n_s == 0 | n_r == 0)) %>%
  group_by(psi, theta, problem, agent, round) %>% 
  mutate(n_round = n(), 
         n_round_s = sum(is.na(r)),
         n_round_r = n_round - n_round_s,
         round_freq = round(sum(if_else(r == r_low, 1, 0), na.rm = TRUE)/n_round_r, 2)) # compute round-level frequencies


## compute median round-level frequencies ...

### ... for each sampled frequency on the trial level
  
freq_high_trial <- freq_high %>% distinct(psi, threshold, theta, problem, agent, round, trial_freq, round_freq) # drop redundant rows
freq_low_trial <- freq_low %>% distinct(psi, threshold, theta, problem, agent, round, trial_freq, round_freq) 
freq_trial <- bind_rows(freq_high_trial, freq_low_trial)
freq_trial_median <- freq_trial %>% 
  group_by(psi, theta, trial_freq) %>%
  summarise(median_round_freq = median(round_freq, na.rm = TRUE)) # compute median round-level frequencies for each parameter combination and trial-level frequency

### ... for each latent probability

freq_high_latent <- freq_high %>% 
  distinct(psi, threshold, theta, problem, agent, round, p_r_high, round_freq) %>% # drop redundant rows
  mutate(p_r = p_r_high) %>% 
  select(!p_r_high)
freq_low_latent <- freq_low %>% 
  distinct(psi, threshold, theta, problem, agent, round, p_r_low, round_freq) %>%  # drop redundant rows
  mutate(p_r = p_r_low) %>% 
  select(!p_r_low)
freq_latent <- bind_rows(freq_high_latent, freq_low_latent)
freq_latent_median <- freq_latent %>% 
  group_by(psi, theta, p_r) %>%
  summarise(median_round_freq = median(round_freq, na.rm = TRUE)) # compute median round-level frequencies for each parameter combination and trial-level frequency

# plot data

## median for trial level frequencies
undersampling_trial <- freq_trial_median %>% 
  ggplot(aes(x = trial_freq, y = median_round_freq, color = as.factor(theta))) +
  geom_jitter(size = 2) + 
  facet_wrap(~psi, labeller = labeller(psi = as_labeller(label_psi, default = label_parsed))) +
  scale_x_continuous(limits = c(-.1, 1.1), breaks = seq(0, 1, .5)) + 
  scale_y_continuous(limits = c(-.1, 1.1), breaks = seq(0, 1, .5)) + 
  labs(x = "Sampled Probability Across Choice Trial",
       y = "Sampled Probability\nWithin Comparison Round", 
       color = "Threshold\n(Stopping Rule)") +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") + 
  scale_color_scico_d(palette = "imola") + 
  theme_minimal(base_size = 20)

## median for latent probabilities
undersampling_latent <- freq_latent_median %>% 
  ggplot(aes(x = p_r, y = median_round_freq, color = as.factor(theta))) +
  geom_jitter(size = 2) + 
  facet_wrap(~psi, labeller = labeller(psi = as_labeller(label_psi, default = label_parsed))) +
  scale_x_continuous(limits = c(-.1, 1.1), breaks = seq(0, 1, .5)) + 
  scale_y_continuous(limits = c(-.1, 1.1), breaks = seq(0, 1, .5)) + 
  labs(x = "Ground-Truth Probability",
       y = "Sampled Probability\nWithin Comparison Round", 
       color = "Threshold\n(Stopping Rule)") +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") + 
  scale_color_scico_d(palette = "imola") + 
  theme_minimal(base_size = 20)

# merge and save plot
undersampling_latent + undersampling_trial + 
  plot_layout(ncol = 1, guides = "collect") + 
  plot_annotation(tag_levels = "A") & 
  theme(plot.tag = element_text(size = 24, face = "plain"))
ggsave(file = "manuscript/figures/undersampling.png", width = 14, height = 10)


# risk aversion -----------------------------------------------------------

# prepare data 
rates <- choices %>% 
  filter(!c(n_s == 0 | n_r == 0)) %>% # remove choices where an option was not attended 
  mutate(r_averse = ifelse(choice == "s", 1, 0)) %>% # risk averse choice
  group_by(model, psi, threshold, theta, r_averse) %>% 
  summarise(n = n()) %>% 
  mutate(rate = round(n/sum(n), 2)) %>% 
  ungroup() %>%
  filter(!(r_averse == 0))

r_averse_summary <- rates %>%  
  filter(model == "summary" & threshold == "relative") %>% 
  #filter(psi > .9 | psi == .5 | psi == (1-.9)) %>% 
  ggplot(aes(psi, rate, group = theta, color = theta)) +
  scale_color_scico(palette = "imola", alpha = .7) +
  scale_x_continuous(limits = c(-.1, 1.1), breaks = seq(0, 1, length.out = 3)) +
  scale_y_continuous(limits = c(-.1, 1.1), breaks = seq(0, 1, length.out = 3)) +
  labs(title = "Summary Comparison", 
       x = "Switching Probability\n(Search Rule)",
       y = "% Safe Choices",
       color = "Threshold\n(Stopping Rule)") +
  geom_line(linewidth = 1) + 
  geom_point(size = 3) +
  theme_minimal(base_size = 20)

r_averse_roundwise <- rates %>%
  filter(model == "roundwise" & threshold == "relative") %>% 
  #filter(psi > .9 | psi == .5 | psi == (1-.9)) %>% 
  ggplot(aes(psi, rate, group = theta, color = as.factor(theta))) +
  scale_color_scico_d(palette = "imola", alpha = .7) + 
  scale_x_continuous(limits = c(-.1, 1.1), breaks = seq(0, 1, length.out = 3)) +
  scale_y_continuous(limits = c(-.1, 1.1), breaks = seq(0, 1, length.out = 3)) +
  labs(title = "Roundwise Comparison", 
       x = "Switching Probability\n(Search Rule)",
       y = "% Safe Choices",
       color = "Threshold\n(Stopping Rule)") +
  geom_line(linewidth = 1) + 
  geom_point(size = 3) +
  theme_minimal(base_size = 20)

r_averse_summary + r_averse_roundwise + plot_annotation(tag_levels = "A")
ggsave(file = "manuscript/figures/rates_risk_aversion.png", width = 14, height = 6)


# weighting function ---------------------------------------------------------


# check MCMC statistics / convergence 

# scale reduction factor 
max(cpt$Rhat) # 1.0014 ----> < 1.00 
min(cpt$n.eff) # 17,000

# prepare data
weights <- cpt %>%
  select(model, psi, threshold, theta, parameter, mean) %>%
  pivot_wider(names_from = parameter, values_from = mean) %>% 
  select(-c(alpha, rho)) %>%
  expand_grid(p = seq(0, 1, .05)) %>% # create vector of sampled relative frequencies
  mutate(w = round(  (delta * p^gamma)/ ((delta * p^gamma)+(1-p)^gamma), 2)) # compute decision weights (see Goldstein & Einhorn, 1987) using the parameter estimates  

# plot data

## summary 

cpt_summary <- cpt %>% filter(model == "summary")
weights_summary <- weights %>% filter(model == "summary")

#### gamma
gamma_summary <- cpt_summary %>%
  filter(parameter == "gamma", threshold == "relative") %>%
  ggplot(aes(psi, mean, color = psi)) + 
  scale_color_scico(palette = "tokyo", end = .8) +
  facet_wrap(~theta, nrow = 1, labeller = labeller(theta = as_labeller(label_theta, default = label_parsed))) +
  scale_x_continuous(limits = c(-0.1,1.1), breaks = seq(0,1, length.out = 3)) + 
  scale_y_continuous(limits =c(-.1, 2.1), breaks = seq(0,2, length.out = 3)) +
  labs(x = "Switching Probability (Search Rule)", 
       y = expression(paste("Curvature  ", gamma)),
       color = "Switching\nProbability") +
  geom_linerange(aes(ymin=`2.5%`, ymax=`97.5%`), linewidth = 1) + 
  geom_point(size = 3) +
  geom_line(linewidth = 1) +
  theme_minimal(base_size = 20)

#### delta
delta_summary <- cpt_summary %>%
  filter(parameter == "delta", threshold == "relative") %>%
  ggplot(aes(psi, mean, color = psi)) +
  scale_color_scico(palette = "tokyo", end = .8) +
  facet_wrap(~theta, nrow = 1, labeller = labeller(theta = as_labeller(label_theta, default = label_parsed))) +
  scale_x_continuous(limits = c(-0.1,1.1), breaks = seq(0,1, length.out = 3)) +
  scale_y_continuous(limits = c(-0.1, 10.1), breaks = seq(0, 10, length.out = 3)) +
  labs(x = "Switching Probability (Search Rule)", 
       y = expression(paste("Elevation  ", delta)), 
       color = "Switching\nProbability") +
  geom_linerange(aes(ymin=`2.5%`, ymax=`97.5%`), linewidth = 1) + 
  geom_point(size = 3) +
  geom_line(linewidth = 1) +
  theme_minimal(base_size = 20)

####  probability weighting
wf_summary <- weights_summary %>% 
  filter(threshold == "relative") %>% 
  ggplot(aes(p, w, group = psi, color = psi)) +
  scale_color_scico(palette = "tokyo", end = .8) +
  facet_wrap(~theta, nrow = 1, labeller = labeller(theta = as_labeller(label_theta, default = label_parsed))) + 
  scale_x_continuous(breaks = seq(0, 1, length.out = 3)) +
  scale_y_continuous(breaks = seq(0, 1, length.out = 3)) +
  labs(x = TeX("$\\p_{high}$"),
       y = TeX("$w(\\p_{high})$"),
       color = "Switching\nProbability") +
  geom_line(linewidth = 1) +
  theme_minimal(base_size = 20)

# merge and save plots

wf_summary + gamma_summary + delta_summary + plot_layout(ncol = 1, guides = "collect") + plot_annotation(tag_levels = "A")
ggsave(file = "manuscript/figures/cpt_weighting_summary.png", width = 14, height = 10)

## roundwise

cpt_roundwise <- cpt %>% filter(model == "roundwise", !(psi == 1 & theta == 1))
weights_roundwise <- weights %>% filter(model == "roundwise", !(psi == 1 & theta == 1))

#### gamma
gamma_roundwise <- cpt_roundwise %>%
  filter(parameter == "gamma", threshold == "relative") %>%
  ggplot(aes(psi, mean, color = psi)) + 
  scale_color_scico(palette = "tokyo", end = .8) +
  facet_wrap(~theta, nrow = 1, labeller = labeller(theta = as_labeller(label_theta, default = label_parsed))) +
  scale_x_continuous(limits = c(-0.1,1.1), breaks = seq(0,1, length.out = 3)) + 
  scale_y_continuous(limits =c(-.1, 2.1), breaks = seq(0,2, length.out = 3)) +
  labs(x = "Switching Probability (Search Rule)", 
       y = expression(paste("Curvature  ", gamma)),
       color = "Switching\nProbability") +
  geom_linerange(aes(ymin=`2.5%`, ymax=`97.5%`), linewidth = 1) + 
  geom_point(size = 3) +
  geom_line(linewidth = 1) +
  theme_minimal(base_size = 20)

#### delta
delta_roundwise <- cpt_roundwise %>%
  filter(parameter == "delta", threshold == "relative") %>%
  ggplot(aes(psi, mean, color = psi)) +
  scale_color_scico(palette = "tokyo", end = .8) +
  facet_wrap(~theta, nrow = 1, labeller = labeller(theta = as_labeller(label_theta, default = label_parsed)), scales = "free") +
  scale_x_continuous(limits = c(-0.1,1.1), breaks = seq(0,1, length.out = 3)) +
  scale_y_continuous(limits = c(-0.1, 2.1), breaks = seq(0,2, length.out = 3)) +
  labs(x = "Switching Probability (Search Rule)", 
       y = expression(paste("Elevation  ", delta)), 
       color = "Switching\nProbability") +
  geom_linerange(aes(ymin=`2.5%`, ymax=`97.5%`), linewidth = 1) + 
  geom_point(size = 3) +
  geom_line(linewidth = 1) +
  theme_minimal(base_size = 20)

####  probability weighting
wf_roundwise <- weights_roundwise %>% 
  filter(threshold == "relative") %>% 
  ggplot(aes(p, w, group = psi, color = psi)) +
  scale_color_scico(palette = "tokyo", end = .8) +
  facet_wrap(~theta, nrow = 1, labeller = labeller(theta = as_labeller(label_theta, default = label_parsed))) + 
  scale_x_continuous(breaks = seq(0, 1, length.out = 3)) +
  scale_y_continuous(breaks = seq(0, 1, length.out = 3)) +
  labs(x = TeX("$\\p_{high}$"),
       y = TeX("$w(\\p_{high})$"), 
       color = "Switching\nProbability") +
  geom_line(linewidth = 1) +
  theme_minimal(base_size = 20)

# merge and save plots

wf_roundwise + gamma_roundwise + delta_roundwise + plot_layout(ncol = 1, guides = "collect") + plot_annotation(tag_levels = "A")
ggsave(file = "manuscript/figures/cpt_weighting_roundwise.png", width = 14, height = 10)


# value function ---------------------------------------------------------

# prepare data

values <- cpt %>%
  select(model, psi, threshold, theta, parameter, mean) %>%
  pivot_wider(names_from = parameter, values_from = mean) %>%
  select(-c(gamma, delta, rho)) %>%
  expand_grid(x = seq(0, 20, .5)) %>%  # create vector of possible outcomes
  mutate(v = round(x^alpha, 2)) # compute subjective values on the basis of estimated parameters

# plot data 

## summary

values_summary <- values %>% filter(model == "summary")

### alpha
alpha_summary <- cpt_summary %>%
  filter(parameter == "alpha", threshold == "relative") %>% 
  ggplot(aes(psi, mean, color = psi)) +
  scale_color_scico(palette = "tokyo", end = .8) + 
  facet_wrap(~theta, nrow = 1, labeller = labeller(theta = as_labeller(label_theta, default = label_parsed))) +
  scale_x_continuous(limits = c(-0.1, 1.1), breaks = seq(0,1, length.out = 3)) + 
  scale_y_continuous(limits = c(-0.1, 2.1), breaks = seq(0,2, length.out = 3)) + 
  labs(x = "Switching Probability (Search Rule)", 
       y = expression(paste("Outcome Sensitivity  ", alpha)),
       color = "Switching\nProbability") +
  geom_linerange(aes(ymin=`2.5%`, ymax=`97.5%`), linewidth = 1) +
  geom_point(size = 3) +
  geom_line(linewidth = 1) +
  theme_minimal(base_size = 20)

### value function 
vf_summary <- values_summary %>% 
  filter(threshold == "relative") %>% 
  ggplot(aes(x, v, group = psi, color = psi)) +
  scale_color_scico(palette = "tokyo", end = .8) +
  facet_wrap(~theta, nrow = 1, labeller = labeller(theta = as_labeller(label_theta, default = label_parsed))) + 
  scale_x_continuous(limits = c(-1, 21), breaks = seq(0, 20, length.out = 3)) +
  scale_y_continuous(limits = c(-1, 21), breaks = seq(0, 20, length.out = 3)) +
  labs(x = "Sampled Outcome",
       y = "Subjective Value",
       color = "Switching\nProbability") +
  geom_line(linewidth = 1) +
  theme_minimal(base_size = 20)

# merge and save plots
vf_summary + alpha_summary + plot_layout(ncol = 1, guides = "collect") + plot_annotation(tag_levels = "A")
ggsave(file = "manuscript/figures/cpt_value_summary.png", width = 14, height = 7)

## round-wise

values_roundwise <- values %>% filter(model == "roundwise", !(psi == 1 & theta == 1))

### alpha
alpha_roundwise <- cpt_roundwise %>%
  filter(parameter == "alpha", threshold == "relative") %>% 
  ggplot(aes(psi, mean, color = psi)) +
  scale_color_scico(palette = "tokyo", end = .8) + 
  facet_wrap(~theta, nrow = 1, labeller = labeller(theta = as_labeller(label_theta, default = label_parsed))) +
  scale_x_continuous(limits = c(-0.1, 1.1), breaks = seq(0,1, length.out = 3)) + 
  scale_y_continuous(limits = c(-0.1, 2.1), breaks = seq(0,2, length.out = 3)) + 
  labs(x = "Switching Probability (Search Rule)", 
       y = expression(paste("Outcome Sensitivity  ", alpha)),
       color = "Switching\nProbability") +
  geom_linerange(aes(ymin=`2.5%`, ymax=`97.5%`), linewidth = 1) +
  geom_point(size = 3) +
  geom_line(linewidth = 1) +
  theme_minimal(base_size = 20)

### value function 
vf_roundwise <- values_roundwise %>% 
  filter(threshold == "relative") %>% 
  ggplot(aes(x, v, group = psi, color = psi)) +
  scale_color_scico(palette = "tokyo", end = .8) +
  facet_wrap(~theta, nrow = 1, labeller = labeller(theta = as_labeller(label_theta, default = label_parsed))) + 
  scale_x_continuous(limits = c(-1, 21), breaks = seq(0, 20, length.out = 3)) +
  scale_y_continuous(limits = c(-1, 21), breaks = seq(0, 20, length.out = 3)) +
  labs(x = "Sampled Outcome",
       y = "Subjective Value",
       color = "Switching\nProbability") +
  geom_line(linewidth = 1) +
  theme_minimal(base_size = 20)

# merge and save plots
vf_roundwise + alpha_roundwise + plot_layout(ncol = 1, guides = "collect") + plot_annotation(tag_levels = "A")
ggsave(file = "manuscript/figures/cpt_value_roundwise.png", width = 14, height = 7)