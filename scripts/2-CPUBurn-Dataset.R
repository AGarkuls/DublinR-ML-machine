# File-Name:				2-CPUBurn-Dataset.R
# Date:						2015-03-07
# Author:					Eoin Brazil
# Email:					eoin.brazil@gmail.com
# Purpose:					Format and explore the Kaggle CPU Burn Dataset for use in ML
# Data Used:				train.csv - http://inclass.kaggle.com/c/model-t4
# R version Used:			3.1.2
# Packages Used:			caret, party, tabplot, kernlab, doMC, rpart, pls, C50, car, corrplot
# Output Files:				cpuburn.logisticReg.rdata, cpuburn.rpartTune.rdata, cpuburn.pls.rdata
# Data Output:			

# Version:					1.0
# Change log:				Initial version

# Copyright (c) 2015, under the Simplified BSD License.  
# For more information on FreeBSD see: http://www.opensource.org/licenses/bsd-license.php
# All rights reserved.                    

# For data and modeling
library(caret)
library(party)
library(kernlab)
library(doMC)
library(car)
library(corrplot)
library(pROC)
library(tabplot)
library(rpart)
library(ipred)
library(pls)
library(C50)

registerDoMC(8)

# Replace the path here with the appropriate one for your machine - this assumes an AMI RStudio on EC2 (see http://www.louisaslett.com/RStudio_AMI/)
myprojectpath = "/home/ubuntu/"

# Replace the path here with the appropriate one for your machine
scriptpath = paste(myprojectpath, "scripts/", sep="")
datapath = paste(myprojectpath, "data/", sep="")
graphpath = paste(myprojectpath, "graphs/", sep="")

# Load and take a look at dataframe for processing
cpuburn.df = read.csv(paste(datapath, "train.csv", sep=""))

# Explore the first ten records of the dataset to take a peek
head(cpuburn.df)

# Look to get a summary of the dataset for each variable in the dataframe
summary(cpuburn.df)

# Recode the categorical variable of machine id to a set of numeric
cpuburn.df$a <- recode(cpuburn.df$m_id,"'a'=1;else=0",as.factor.result=FALSE, as.numeric.result=TRUE)
cpuburn.df$b <- recode(cpuburn.df$m_id,"'b'=1;else=0",as.factor.result=FALSE, as.numeric.result=TRUE)
cpuburn.df$c <- recode(cpuburn.df$m_id,"'c'=1;else=0",as.factor.result=FALSE, as.numeric.result=TRUE)
cpuburn.df$d <- recode(cpuburn.df$m_id,"'d'=1;else=0",as.factor.result=FALSE, as.numeric.result=TRUE)
cpuburn.df$e <- recode(cpuburn.df$m_id,"'e'=1;else=0",as.factor.result=FALSE, as.numeric.result=TRUE)
cpuburn.df$f <- recode(cpuburn.df$m_id,"'f'=1;else=0",as.factor.result=FALSE, as.numeric.result=TRUE)
cpuburn.df$g <- recode(cpuburn.df$m_id,"'g'=1;else=0",as.factor.result=FALSE, as.numeric.result=TRUE)

# Add a numeric day of week variable (day returns 0-6)
cpuburn.df$sun <- recode(as.POSIXlt(cpuburn.df$sample_time)$wday,"0=1;else=0")
cpuburn.df$mon <- recode(as.POSIXlt(cpuburn.df$sample_time)$wday,"1=1;else=0")
cpuburn.df$tue <- recode(as.POSIXlt(cpuburn.df$sample_time)$wday,"2=1;else=0")
cpuburn.df$wed <- recode(as.POSIXlt(cpuburn.df$sample_time)$wday,"3=1;else=0")
cpuburn.df$thu <- recode(as.POSIXlt(cpuburn.df$sample_time)$wday,"4=1;else=0")
cpuburn.df$fri <- recode(as.POSIXlt(cpuburn.df$sample_time)$wday,"5=1;else=0")
cpuburn.df$sat <- recode(as.POSIXlt(cpuburn.df$sample_time)$wday,"6=1;else=0")

# Identify and remove a number skewed variables
needed = colnames(cpuburn.df) %in% c("app03_proccount","app06_dirio","app06_bufio","app06_pgflts","app06_proccount", "app06_pagesgbl")
cpuburn.df <- (cpuburn.df[,!needed])

# Plot all the variables in the DF using a tableplot
tableplot(cpuburn.df)

# Identify variables with near zero variance
cpuburn.variables.nearZeroVar <- nearZeroVar(cpuburn.df)
cpuburn.variables.nearZeroVar.names <- colnames(cpuburn.df[, cpuburn.variables.nearZeroVar])

# Identify highly correlated variables 0.75+
cpuburn.corr <- cor(cpuburn.df[,-c(1:2)])
cpuburn.variables.corr <- findCorrelation(cpuburn.corr, cutoff=0.75)
cpuburn.variables.corr.names <- colnames(cpuburn.df[,cpuburn.variables.corr])

# Combine the variables which are highly correlated and with near zero variance and remove them excluding the target variable as it happens to fall in this combined group
cpuburn.variables.to.filter <- unique(c(cpuburn.variables.nearZeroVar,cpuburn.variables.corr))
cpuburn.variables.to.filter.names <- colnames(cpuburn.df[,cpuburn.variables.to.filter])
cpuburn.variables.to.filter <- cpuburn.variables.to.filter[which(cpuburn.variables.to.filter!=69)]
cpuburn.data.df.reduced <- cpuburn.df[,-cpuburn.variables.to.filter]

tableplot(cpuburn.data.df.reduced)

# Split the data into two sets, a training set and a test set to use in conjunction with the classifers
trainIndices = createDataPartition(cpuburn.data.df.reduced$cpu_01_busy, p = 0.8, list = F)
unwanted = colnames(cpuburn.data.df.reduced) %in% c("sample_time","m_id")
cpuburn.data.df.reduced.train = cpuburn.data.df.reduced[trainIndices,!unwanted]
cpuburn.data.df.reduced.test  = cpuburn.data.df.reduced[!1:nrow(cpuburn.data.df.reduced) %in% trainIndices,!unwanted]

# Simple single tree example
SingleTree = ctree(is_cpu_busy ~ ., data = cpuburn.data.df.reduced.train)
SingleTree
plot(SingleTree, type="simple")

# Set the seed to ensure that you can compare the results of the classifers
set.seed(1133)
# Use the 'caret' package to train a logistic regression classifier and save it to a local rdata file
cpuburn.logisticReg <- train(cpu_01_busy ~ ., data=cpuburn.data.df.reduced.train,method="glm", trControl=trainControl(method="repeatedcv", repeats=5, classProbs=TRUE))
save(cpuburn.logisticReg,compress="bzip2",file="/home/ubuntu/cpuburn.logisticReg.rdata")

# Simiarly, set the seed, train with 'caret' and save the resulting classifiers (randomForest and PartialLeastSquares respectively)
set.seed(1133)
cpuburn.rpartTune <- train(cpu_01_busy ~ ., data=cpuburn.data.df.reduced.train, method="rpart", tuneLength=10, trControl=trainControl(method="repeatedcv", repeats=5, classProbs=TRUE))
save(cpuburn.rpartTune,compress="bzip2",file="/home/ubuntu/cpuburn.rpartTune.rdata")
set.seed(1133)
cpuburn.pls <- train(cpu_01_busy ~ ., data=cpuburn.data.df.reduced.train,method="pls", preProc=c("center", "scale"), tuneLength=10, trControl=trainControl(method="repeatedcv", repeats=5, classProbs=TRUE))
save(cpuburn.pls,compress="bzip2",file="/home/ubuntu/cpuburn.pls.rdata")

# To copy these files to your local machine you will need to use a command similar to this but you will need to change the values as appropriate
# scp -i <YOUR_KEY>.pem ubuntu@<EC2_HOST_PUBLIC_IP_ADDRESS>:/home/ubuntu/cpuburn.pls.rdata.bz2 <PATH_AND_FOLDER_ON_YOUR_LOCAL_MACHINE>/cpuburn.pls.rdata