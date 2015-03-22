# File-Name:				  1-JobScheduling-Dataset.R
# Date:               2015-02-15
# Author:					    Eoin Brazil
# Email:              eoin.brazil@gmail.com
# Purpose:            Format and explore the schedulingData Dataset for use in ML
# Data Used:				  AppliedPredictiveModeling - schedulingData and script from Max Kuhn
# R version Used:			3.1.2
# Packages Used:			AppliedPredictiveModeling, caret, rpart, C50, plyr, mda, earth, ipred, tabplot, nnet, kernlab, doMC, e1071
# Output Files:				
# Data Output:			

# Version:					  1.0
# Change log:         Initial version

# Copyright (c) Max Kuhn - Applied Predictive Modeling
# This example uses code and samples from the Applied Predictive Modeling book

# For data and modeling
library(AppliedPredictiveModeling)
library(caret)
library(rpart)
library(C50)
library(plyr)
library(mda)
library(earth)
library(ipred)
library(tabplot)
library(nnet)
library(kernlab)
library(doMC)
library(e1071)

# Replace the value '2' with the appropriate number of cores available in your machine
registerDoMC(2)

# Replace the path here with the appropriate one for your machine
myprojectpath = "/Users/eoinbrazil/Desktop/DublinR/TreesAndForests/DublinR-ML-machines/"

# Set the working directory to the current location for the project files
setwd(myprojectpath)

# Replace the path here with the appropriate one for your machine
scriptpath = paste(myprojectpath, "scripts/", sep="")
datapath = paste(myprojectpath, "data/", sep="")
graphpath = paste(myprojectpath, "graphs/", sep="")

# Load and take a look at the data
data(schedulingData)
head(schedulingData)
summary(schedulingData)

set.seed(1212)

# Make a vector of predictor names
predictors <- names(schedulingData)[!(names(schedulingData) %in% c("Class"))]

tableplot(schedulingData[, c( "Class", predictors)])

trainingSet <- createDataPartition(schedulingData$Class, p = .8, list = FALSE)
# As the distribution is skewed and contains lots of zeros, one is added to allow log transforming the data
schedulingData$NumPending <- schedulingData$NumPending + 1

# Splitting the data into training and testing data
trainData <- schedulingData[ trainingSet,]
testData  <- schedulingData[-trainingSet,]

modForm <- as.formula(Class ~ Protocol + log10(Compounds) + log10(InputFields)+ log10(Iterations) + log10(NumPending) + Hour + Day)

### Create the cost matrix
costMatrix <- ifelse(diag(4) == 1, 0, 1)
costMatrix[1,4] <- 10
costMatrix[1,3] <- 5
costMatrix[2,4] <- 5
costMatrix[2,3] <- 5
rownames(costMatrix) <- levels(trainData$Class)
colnames(costMatrix) <- levels(trainData$Class)
costMatrix
# Create the cost function
cost <- function(pred, obs)
{
  isNA <- is.na(pred)
  if(!all(isNA))
  {
    pred <- pred[!isNA]
    obs <- obs[!isNA]
    
    cost <- ifelse(pred == obs, 0, 1)
    if(any(pred == "VF" & obs == "L")) cost[pred == "L" & obs == "VF"] <- 10
    if(any(pred == "F" & obs == "L")) cost[pred == "F" & obs == "L"] <- 5
    if(any(pred == "F" & obs == "M")) cost[pred == "F" & obs == "M"] <- 5
    if(any(pred == "VF" & obs == "M")) cost[pred == "VF" & obs == "M"] <- 5
    out <- mean(cost)
  } else out <- NA
  out
}

# Create the summary function to be used with caret's train() function
costSummary <- function (data, lev = NULL, model = NULL)
{
  if (is.character(data$obs))  data$obs <- factor(data$obs, levels = lev)
  c(postResample(data[, "pred"], data[, "obs"]),
    Cost = cost(data[, "pred"], data[, "obs"]))
}

ctrl <- trainControl(method="repeatedcv", repeats=5, summaryFunction=costSummary)

# Use the caret bag() function to bag the cost-sensitive CART model
rpCost <- function(x, y)
{
  costMatrix <- ifelse(diag(4) == 1, 0, 1)
  costMatrix[4, 1] <- 10
  costMatrix[3, 1] <- 5
  costMatrix[4, 2] <- 5
  costMatrix[3, 2] <- 5
  tmp <- x
  tmp$y <- y
  rpart(y~., data = tmp, control = rpart.control(cp = 0), parms =list(loss = costMatrix))
}

rpPredict <- function(object, x) predict(object, x)

rpAgg <- function (x, type = "class")
{
  pooled <- x[[1]] * NA
  n <- nrow(pooled)
  classes <- colnames(pooled)
  for (i in 1:ncol(pooled))
  {
    tmp <- lapply(x, function(y, col) y[, col], col = i)
    tmp <- do.call("rbind", tmp)
    pooled[, i] <- apply(tmp, 2, median)
  }
  pooled <- apply(pooled, 1, function(x) x/sum(x))
  if (n != nrow(pooled)) pooled <- t(pooled)
  out <- factor(classes[apply(pooled, 1, which.max)], levels = classes)
  out
}

rpCostBag <- train(trainData[, predictors], trainData$Class, "bag", B = 50, bagControl = bagControl(fit = rpCost, predict = rpPredict, aggregate = rpAgg, downSample = FALSE, allowParallel = FALSE), trControl = ctrl)
rpCostBag

rpFit <- train(x = trainData[, predictors], y = trainData$Class, method = "rpart", metric = "Cost", maximize = FALSE, tuneLength = 20, trControl = ctrl)
rpFit

# Cost Sensitive caret
set.seed(1412)
rpFitCost <- train(x = trainData[, predictors], y = trainData$Class, method = "rpart", metric = "Cost", maximize = FALSE, tuneLength = 20, parms =list(loss = costMatrix), trControl = ctrl)
rpFitCost

c5Grid <- expand.grid(trials = c(1, (1:10)*10), model = "tree", winnow = c(TRUE, FALSE))
c50Fit <- train(x = trainData[, predictors], y = trainData$Class, method = "C5.0", metric = "Cost", maximize = FALSE, tuneGrid = c5Grid, trControl = ctrl)
c50Fit

fdaFit <- train(modForm, data = trainData, method = "fda", metric = "Cost", maximize = FALSE, tuneLength = 25, trControl = ctrl)
fdaFit

bagFit <- train(x = trainData[, predictors], y = trainData$Class, method = "treebag", metric = "Cost", maximize = FALSE, nbagg = 50, trControl = ctrl)
bagFit

modelList <- list("CART (Costs)" = rpFitCost, CART = rpFit, C5.0 = c50Fit, FDA = fdaFit, Bagging = bagFit, "Bagging (Costs)" = rpCostBag)
rs <- resamples(modelList)
summary(rs)
plot(bwplot(rs, metric = "Cost"))