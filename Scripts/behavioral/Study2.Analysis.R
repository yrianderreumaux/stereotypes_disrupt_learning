#Load data from google drive
id <- "1hVhWUzRQ--hhPxDhj9rIsvo5-R2wpVHk" # google file ID
Study2Data <- read.csv(sprintf("https://docs.google.com/uc?id=%s&export=download", id))
Study2Data$Participant <- as.factor(Study2Data$Participant) #make participant factor

#create variable for face/cloud and prediction type crime/weather
#####
Study2Data$stim_type <- NA
Study2Data$pred_type <- NA
Study2Data$stim_type[Study2Data$Stimuli=="cloudy" | Study2Data$Stimuli=="sunny"] <- "clouds"
Study2Data$stim_type[Study2Data$Stimuli=="white" | Study2Data$Stimuli=="black"] <- "faces"
Study2Data$pred_type[Study2Data$Choice=="rain" | Study2Data$Choice=="sun"] <- "weather"
Study2Data$pred_type[Study2Data$Choice=="no_steal" | Study2Data$Choice=="steal"] <- "crime"
#make it a factor and change ref level 
Study2Data$stim_type <- as.factor(Study2Data$stim_type)
Study2Data$pred_type <- as.factor(Study2Data$pred_type)
Study2Data$stim_type <- relevel(Study2Data$stim_type, ref = "clouds")
Study2Data$pred_type <- relevel(Study2Data$pred_type, ref = "crime")
#####

#set reference group for categorical variables
#####
Study2Data$Condition_eff <- factor(Study2Data$Condition, 
                             levels = c("steal", "steal_clouds", "weather_faces", "weather"))
contrasts(Study2Data$Condition_eff) <- contr.sum(4)
colnames(contrasts(Study2Data$Condition_eff)) = c("steal", "steal_clouds", "weather_faces")

Study2Data$Condition_dum <- factor(Study2Data$Condition, 
                                   levels = c("steal", "steal_clouds", "weather_faces", "weather"))
contrasts(Study2Data$Condition_dum) <- contr.treatment(4, base = 4)
colnames(contrasts(Study2Data$Condition_dum)) = c("steal", "steal_clouds", "weather_faces")

Study2Data$ethnicity_eff <- as.factor(Study2Data$ethnicity)
contrasts(Study2Data$ethnicity_eff) <- contr.treatment(6)
colnames(contrasts(Study2Data$ethnicity_eff)) = c("Black", "Latinx", "Native Hawaiian or Pacific Islander", "Other", "White")

#collapse race per reviewer request
Study2Data$ethnicity_recode <- Study2Data$ethnicity
Study2Data$ethnicity_recode <-dplyr::recode_factor(Study2Data$ethnicity_recode, "Black or African American" = "Other", "Native Hawaiian or Pacific Islander" = "Other", "White" = "Other")
contrasts(Study2Data$ethnicity_recode) <- contr.treatment(3, base = 1) #make "other" reference group
colnames(contrasts(Study2Data$ethnicity_recode)) = c("Latinx", "Asian" )
#####

#run mixed models for learning by condition
######
Study2.model<- glmer(acc~scale(Trial)*Condition_dum+ (scale(Trial)|Participant)+(1|Face_Shown), data = Study2Data, family = "binomial")
Study2.modelPOWER<- glmer(acc~scale(Trial)+Condition_dum+ (1|Participant), data = Study2Data, family = "binomial")
summary(Study2.modelPOWER)
save(Study2.model, file = "study2model.rda") #function to save model to reload later for simulations
Study2.coef <- summary(Study2.model) #removing random effect for stimuli removes convergence issue, but does not change estimates and therefore we are keeping it. 
Study2.effects <- exp(fixef(Study2.model)) #exponentiate coefficients to get OR
Study2.effects.CI <- log(exp(confint(Study2.model,'Condition_dumsteal', level=0.95))) #takes some time to calculate CI

#does race moderate learning?
Study2.race.model<- glmer(acc~scale(Trial)+Condition_dum* ethnicity_eff+(scale(Trial)|Participant)+(1|Face_Shown), data = Study2Data, family = "binomial")
Study2.race.coef <- summary(Study2.race.model) #no effect of race
tab_model(Study2.race.model)

#with race recoded with 3 instead of 5 factors
Study2.race.model.recoded<- glmer(acc~scale(Trial)+Condition_dum*ethnicity_recode+(scale(Trial)|Participant)+(1|Face_Shown), data = Study2Data, family = "binomial")
Study2.race.coef <- summary(Study2.race.model.recoded) #still no effect of race
tab_model(Study2.race.model.recoded)

#Post-hoc simple contrasts
study2.contr <- emmeans(Study2.model, "Condition_dum")
study2.contr.coef <- pairs(study2.contr, adjust = "none")
study2.contr.eff.size <- pairs(study2.contr, adjust = "none", type = "response")

#reviewer requested model looking at whether IMS is associated with learning in Crime Face specifically (see Supplemental Figure 4)
Figure4 <- glmer(acc~scale(Trial)+Condition_dum*scale(IMS)+ (scale(Trial)|Participant)+(1|Face_Shown), data = Study2Data[which(Study2Data$Condition=="steal" | Study2Data$Condition=="weather_faces"),], family = "binomial")
#ggpredict(Study2.model, c("IMS", "Condition_dum"))%>%plot()+theme_classic()
#####

#correlations between all individual differences and accuracy for each condition (for (see Supplemental Figure 1)
#####
#subset individual differences
subDF <- Study2Data[,c(11,18:28)]
#separate conditions
CrimeDF <- subset(subDF, Condition == "steal")
Crime_cloudsDF <- subset(subDF, Condition == "steal_clouds")
WeatherDF <- subset(subDF, Condition == "weather")
Weather_facesDF <- subset(subDF, Condition == "weather_faces")
#run correlations
CrimeDF.cor <- cor(CrimeDF[2:12],  use="complete.obs")
Crime_cloudsDF.cor <- cor(Crime_cloudsDF[2:12],  use="complete.obs")
WeatherDF.cor <- cor(WeatherDF[2:12],  use="complete.obs")
Weather_facesDF.cor <- cor(Weather_facesDF[2:12],  use="complete.obs")
#generate figures (replace for each condition)
CrimeDF.cor.save <- { # Prepare the Corrplot 
  corrplot(Weather_facesDF.cor,  method = 'ellipse', type = 'lower', diag = FALSE);
  # Call the recordPlot() function to record the plot
  recordPlot()
}
#####

##Figure 3 in manuscript
######
my_colors <- wes_palette("GrandBudapest2")[1:4]
my_colors <- wes_palette("GrandBudapest2")[,c("#E6A0C4", "#C6CDF7", "#D8A499", "#7294D4")]
plotColor <- wes_palette(n= 4,"GrandBudapest2")

names(plotColor) <- levels(Study2Data$Condition)
my_colors <- RColorBrewer::brewer.pal(4, "Blues")[2:4]

plotcurve2 <- ggplot(Study2Data, aes(Trial, acc, fill = as.factor(Condition))) + 
  geom_smooth(method = "loess", color ="grey50")+
  scale_y_continuous(name = "Accuracy")+ scale_fill_manual(breaks = c("steal_clouds","weather", "steal", "weather_faces"),
    values = c("#E6A0C4", "#C6CDF7", "#D8A499", "#7294D4"))+
  theme(legend.position = "none",
        panel.grid = element_blank(),
        axis.title = element_blank(),
        panel.background = element_blank()) +
  theme(legend.position = "none", axis.title = element_blank(),
        panel.background = element_blank(),
        panel.border = element_rect(colour = "black", fill=NA, size=1))+
  coord_cartesian(ylim = c(.6, .9))+theme(axis.ticks=element_blank())
#ggsave("plotcurve2", device='jpeg', width = 6, height = 5,dpi=700)
#####

#####Print the results in the order they appear in the manuscript
print('RESULTS FOR STUDY 2')
print('logistic mixed model for learning rates')
print(Study2.coef)
print(Study2.effects)
print(Study2.effects.CI)
print('no effect of race')
print(Study2.race.coef)
print('Post-hoc simple contrasts')
print(study2.contr.coef)
#plot(plotcurve2) #uncomment to plot figure. Takes a minute to run

