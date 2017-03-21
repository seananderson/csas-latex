build.doc <- function(knit.only = FALSE, ## Only knit the document, don't LaTeX it
                      make.pdf  = TRUE, ## Make the PDF from the Postscript
                      doc.name  = "hake-assessment"
                      ){
  ## Use this function to build to doc entirely from within R
  ## Make sure you have created the .RData files by sourcing all.r
  ##  with the create.rdata.file variables set to TRUE.
  ## Once you have done that and run this function once within an R session,
  ##  you can go into the first knitr code chunk in hake-assessment.rnw and
  ##  set the call to load.models.into.parent.env() to FALSE,
  ##  which will save time for doing the build.
  knit(paste0(doc.name,".rnw"))
  if(!knit.only){
    system(paste0("latex -synctex=1 ", doc.name, ".tex"), invisible = FALSE, show.output.on.console = FALSE) ## Press Enter if the command window pauses
    system(paste0("bibtex ", doc.name), invisible = FALSE, show.output.on.console = TRUE)
    system(paste0("latex ", doc.name, ".tex"), invisible = FALSE, show.output.on.console = FALSE) ## Press Enter if the command window pauses
    system(paste0("latex ", doc.name, ".tex"), invisible = FALSE, show.output.on.console = FALSE) ## Press Enter if the command window pauses
    system(paste0("dvips ", doc.name,".dvi"), invisible = FALSE, show.output.on.console = TRUE)
    if(make.pdf){
      shell(paste0("ps2pdf ", doc.name, ".ps")) ## Not sure why I have to use shell instead of system
    }
  }
}

f <- function(x, dec.points = 0){
  ## Format x to have supplied number of decimal points
  ## Make thousands seperated by commas and the number of decimal points given by
  ##  dec.points
  return(format(round(x,dec.points), big.mark = ",", nsmall = dec.points))
}

install.packages.if.needed <- function(package.name, package.install.name, github=FALSE){
  if(github){
    if(!(package.name %in% rownames(installed.packages()))){
      devtools::install_github(package.install.name)
    }
  }else{
    if(!(package.name %in% rownames(installed.packages()))){
      install.packages(package.install.name)
    }
  }
}

split.prior.info <- function(prior.str,
                             dec.points = 1,
                             first.to.lower = FALSE){
  ## Get priors information from prior.str which is a string like
  ## Lognormal(2.0,1.01)
  ## Returns a vector of length 3:
  ## "Lognormal", 2.0, 1.01
  ## if first.to.lower = TRUE, makes the first letter of the name of the prior lower case.
  p <- strsplit(prior.str, "\\(")[[1]]
  if(first.to.lower){
    ## Make the name of the prior lower case
    p[1] <- paste0(tolower(substr(p[1], 1, 1)), substr(p[1], 2, nchar(p[1])))
  }
  p.type <- p[1]
  p <- strsplit(p[2], ",")[[1]]
  p.mean <- f(as.numeric(p[1]), dec.points)
  p.sd <- f(as.numeric(gsub(")", "", p[2])), dec.points)
  return(c(p.type, p.mean, p.sd))
}

cohortCatch <- function(cohort, catage, ages = 0:20) {
  cohort.yrs <- cohort + ages
  caa <- as.matrix(catage[catage$Yr %in% cohort.yrs, as.character(ages)])
  w <- base.model$wtatage
  w$yr <- w$yr * -1
  waa <- w[w$fleet == 1 & w$yr %in% cohort.yrs, ]
  waa <- waa[, names(waa) %in% ages]
  catch.waa <- as.matrix(caa * waa)

  ind <- 1:(nrow(caa) + 1)
  if(length(ind) > length(ages)){
    ind <- 1:nrow(caa)
  }
  cohort.catch <- diag(catch.waa[,ind])
  names(cohort.catch) <- cohort.yrs[1:(nrow(caa))]
  return(cohort.catch)
}

get.age.prop <- function(vec, place = 1){
  ## returns the age prop and the age itself for the place,
  ## where place is 1=max, 2-second highest, etc.
  prop <- rev(sort(vec))
  prop <- prop[place]
  age <- as.numeric(names(vec[vec == prop]))
  return(c(age, prop))
}

get.shade <- function(color, opacity){
  # If color is a single R color string or single number,
  #  returns an rgb string of the specified color and opacity
  # If color is a vector of cR color strings or numbers,
  #  returns a vector of rgb strings of the specified color and opacity.
  # If the opacity argument is non-integer or not between 0 and 99, NULL will be returned.
  # - opacity - 2-decimal-digit string (00-99), i.e. "20" means 20%
  # Notes: format of returned string is #RRGGBBAA
  #        where RR=red, a 2-hexadecimal-digit string
  #        GG=green, a 2-hexadecimal-digit string
  #        BB=blue, a 2-hexadecimal-digit string
  #        AA=alpha or opacity
  #
  # The opacity agrument is scalar and will be applied to all colors.
  if(!(opacity %% 1 == 0) || opacity<0 || opacity>99){
    cat0(.PROJECT_NAME,"->",currFuncName,"opacity argument must be an integer between 0 and 99.")
    return(NULL)
  }
  colorDEC <- col2rgb(color)
  if(is.matrix(colorDEC)){
    colorHEX <- matrix(nrow=3,ncol=ncol(colorDEC))
    shade <- NULL
    for(col in 1:ncol(colorDEC)){
      for(row in 1:nrow(colorDEC)){
        colorHEX[row,col] <- sprintf("%X", colorDEC[row,col])
        if(nchar(colorHEX[row,col])==1){
          colorHEX[row,col] <- paste0("0",colorHEX[row,col])
        }
      }
      shade[col] <- paste0("#",colorHEX[1,col],colorHEX[2,col],colorHEX[3,col],opacity)
    }
  }else{
    colorHEX <- sprintf("%X", colorDEC)
    for(i in 1:length(colorHEX)){
      if(nchar(colorHEX[i])==1){
        colorHEX[i] <- paste0("0",colorHEX[i])
      }
    }
    shade <- paste0("#",colorHEX[1],colorHEX[2],colorHEX[3],opacity)
  }
  return(shade)
}

remove.all.objects.except <- function(vars){
  # Removes every object in the workspace except for what is in the vars list.
  # Upon finishing, the workspace will contain whatever is in the vars list,
  #  plus the object 'remove.all.objects.except' (this function)

  vars <- c(vars, "remove.all.objects.except")
  keep <- match(x = vars, table = ls(all = TRUE, envir = .GlobalEnv))
  if(!any(is.na(keep))){
    rm(list=ls(all = TRUE, envir = .GlobalEnv)[-keep], envir = .GlobalEnv)
  }
}

pad.num <- function(num, digits = 0){
  ## Takes an integer, num and turns it into a string
  ## If the string is less than digits long, it will
  ## be prepended with zeroes
  if(digits < 1) stop("Error in pad.num - digits must be positive\n")
  sapply(num, function(x){ paste0(rep("0", digits - nchar(as.character(x))), as.character(x))})
}

t.pn <- function(){
  ## test pad.num
  cat("pad.num(0, 1) = ", pad.num(0, 1), "\n")
  cat("pad.num(1, 2) = ", pad.num(1, 2), "\n")
  cat("pad.num(10, 2) = ", pad.num(10, 2), "\n")
  cat("pad.num(10, 3) = ", pad.num(10, 3), "\n")
  cat("pad.num(10, 0) = ", pad.num(10, 0), "\n")
}

print.model.message <- function(model.dir.names, model.names, group, model.type){
  ## Print out a message stating the model directory names and pretty names,
  ##  for the group number given. If bridge is TRUE, it is a bridge model group,
  ##  if bridge is FALSE, it is a sensitivity model group.

  cat0("***")
  cat0(model.type, " model group ", group, " directories: ")
  cat(paste0("  ", model.dir.names), sep = "\n")
  cat0(model.type, " model group ", group, " pretty names: ")
  cat(paste0("  ", model.names), sep = "\n")
  cat0("***")
}

curr.fn.finder <- function(skipframes = 0,
                           skipnames = "(FUN)|(.+apply)|(replicate)",
                           ret.if.none = "Not in function",
                           ret.stack = FALSE,
                           extra.perf.per.level = "\t"){
  ## Get the current function name from within the function itself.
  ## Used to prepend the function name to all messages so that the
  ## user knows where the message came from.
  prefix <- sapply(3 + skipframes + 1:sys.nframe(), function(i){
    currv <- sys.call(sys.parent(n = i))[[1]]
    return(currv)
  })
  prefix[grep(skipnames, prefix)] <- NULL
  prefix <- gsub("function \\(.*", "do.call", prefix)
  if(length(prefix)==0){
    return(ret.if.none)
  }else if(ret.stack){
    return(paste(rev(prefix), collapse = "|"))
  }else{
    retval <- as.character(unlist(prefix[1]))
    if(length(prefix) > 1){
      retval <- paste0(paste(rep(extra.perf.per.level, length(prefix) - 1), collapse = ""), retval)
    }
    return(retval)
  }
}

get.curr.func.name <- function(){
  ## Returns the calling function's name followed by ": "
  func.name <- curr.fn.finder(skipframes = 1) # skipframes=1 is there to avoid returning getCurrFunc itself
  ## Strip extraneous whitespace
  func.name <- gsub("\t+", "", func.name)
  func.name <- gsub("\ +", "", func.name)
  func.name <- paste0(func.name,": ")
  return(func.name)
}

cat0 <- function(...){
  ## Wrapper function to make cat have no space and insert a newline at the end.
  ## Inspired by the paste0 function.
  cat(..., "\n", sep = "")
}

number.to.word <- function(x, th = FALSE, cap.first = FALSE){
  ## https://github.com/ateucher/useful_code/blob/master/R/numbers2words.r
  ## Function by John Fox found here:
  ## http://tolstoy.newcastle.edu.au/R/help/05/04/2715.html
  ## Tweaks by AJH to add commas and "and"
  ## if th is TRUE, the th version will be returned, e.g. 4 = fourth
  ## if cap.first is TRUE, the first letter will be capitalized
  helper <- function(x){
    digits <- rev(strsplit(as.character(x), "")[[1]])
    nDigits <- length(digits)
    if(nDigits == 1) as.vector(ones[digits])
    else if(nDigits == 2)
      if(x <= 19) as.vector(teens[digits[1]])
      else trim(paste(tens[digits[2]],
                      Recall(as.numeric(digits[1]))))
    else if (nDigits == 3) trim(paste(ones[digits[3]], "hundred and",
                                      Recall(makeNumber(digits[2:1]))))
    else {
      nSuffix <- ((nDigits + 2) %/% 3) - 1
      if (nSuffix > length(suffixes)) stop(paste(x, "is too large!"))
      trim(paste(Recall(makeNumber(digits[
        nDigits:(3*nSuffix + 1)])),
        suffixes[nSuffix],"," ,
        Recall(makeNumber(digits[(3*nSuffix):1]))))
    }
  }
  trim <- function(text){
    ## Tidy leading/trailing whitespace, space before comma
    text=gsub("^\ ", "", gsub("\ *$", "", gsub("\ ,",",",text)))
    ## Clear any trailing " and"
    text=gsub(" and$","",text)
    ##Clear any trailing comma
    gsub("\ *,$","",text)
  }
  makeNumber <- function(...) as.numeric(paste(..., collapse=""))
  ## Disable scientific notation
  opts <- options(scipen=100)
  on.exit(options(opts))
  ones <- c("", "one", "two", "three", "four", "five", "six", "seven",
            "eight", "nine")
  names(ones) <- 0:9
  teens <- c("ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen",
             "sixteen", " seventeen", "eighteen", "nineteen")
  names(teens) <- 0:9
  tens <- c("twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty",
            "ninety")
  names(tens) <- 2:9
  x <- round(x)
  suffixes <- c("thousand", "million", "billion", "trillion")
  if (length(x) > 1) return(trim(sapply(x, helper)))
  j <- helper(x)
  ## Cgrandin added the 'th' bit
  if(th){
    j <- strsplit(j, " ")[[1]]
    first <- j[-length(j)]
    last <- j[length(j)]
    if(last == "one"){
      last <- "first"
    }else if(last == "two"){
      last <- "second"
    }else if(last == "three"){
      last <- "third"
    }else if(last == "five"){
      last <- "fifth"
    }else if(last == "eight"){
      last <- "eighth"
    }else if(last == "nine"){
      last <- "ninth"
    }else if(last == "twelve"){
      last <- "twelfth"
    }else if(last == "twenty"){
      last <- "twentieth"
    }else if(last == "thirty"){
      last <- "thirtieth"
    }else if(last == "forty"){
      last <- "fortieth"
    }else if(last == "fifty"){
      last <- "fiftieth"
    }else if(last == "sixty"){
      last <- "sixtieth"
    }else if(last == "seventy"){
      last <- "seventieth"
    }else if(last == "eighty"){
      last <- "eightieth"
    }else if(last == "ninety"){
      last <- "ninetieth"
    }else{
      last <- paste0(last, "th")
    }
    j <- paste(c(first, last), collapse = " ")
  }
  if(cap.first){
    j <- paste0(toupper(substr(j, 1, 1)), substr(j, 2, nchar(j)))
  }
  return(j)
}

## *****************************************************************************
## The following three functions give the ability to assign more than one variable at once.
## Example Call;  Note the use of set.elems()  AND  `%=%`
## Right-hand side can be a list or vector
## set.elems(a, b, c)  %=%  list("hello", 123, list("apples, oranges"))
## set.elems(d, e, f) %=%  101:103
## # Results:
## > a
## [1] "hello"
## > b
## [1] 123
## > c
## [[1]]
## [1] "apples, oranges"
## > d
## [1] 101
## > e
## [1] 102
## > f
## [1] 103

## Generic form
"%=%" <- function(l, r, ...) UseMethod("%=%")

## Binary Operator
"%=%.lhs" <- function(l, r, ...) {
  env <- as.environment(-1)
  if (length(r) > length(l))
    warning("RHS has more args than LHS. Only first", length(l), "used.")
  if (length(l) > length(r))  {
    warning("LHS has more args than RHS. RHS will be repeated.")
    r <- extend.to.match(r, l)
  }
  for(II in 1:length(l)) {
    do.call('<-', list(l[[II]], r[[II]]), envir = env)
  }
}

## Used if LHS is larger than RHS
extend.to.match <- function(src, destin) {
  s <- length(src)
  d <- length(destin)
  # Assume that destin is a length when it is a single number and src is not
  if(d==1 && s>1 && !is.null(as.numeric(destin)))
    d <- destin
  dif <- d - s
  if (dif > 0) {
    src <- rep(src, ceiling(d/s))[1:d]
  }
  return (src)
}

set.elems <- function(...) {
  list.tmp <-  as.list(substitute(list(...)))[-1L]
  class(list.tmp) <-  "lhs"
  return(list.tmp)
}

cbind.fill <- function(...){
  ## equivalent of cbind(df, xx) where df is an empty data frame.
  nm <- list(...)
  nm <- lapply(nm, as.matrix)
  n <- max(sapply(nm, nrow))
  do.call(cbind, lapply(nm, function (x)
    rbind(x, matrix(, n-nrow(x), ncol(x)))))
}

strip.columns <- function(vec, names){
  ## Return a vector which is the same as the vector 'vec'
  ## but with the matching col.names removed
  return(vec[!names(vec) %in% names])
}

get.align <- function(num,
                      first.left = TRUE, ## Keep the first column left-justified
                                         ## If FALSE, it will be justified according to the 'just' argument
                      just = "r"         ## just is the justification to use for the columns, "r", "l", or "c"
                      ){
  ## Returns a character vector used in the align argument of the xtable command.
  ## e.g. posterior output tables, reference point tables. Most tables really.
  ## num is the number of columns in the table
  if(first.left){
    align <- c("l", "l")
  }else{
    align <- c(just, just)
  }
  for(i in 1:(num-1)){
    align <- c(align, just)
  }
  return(align)
}

rc <- rich.colors.short <- function(n, alpha = 1){
  x <- seq(0, 1, length = n)
  r <- 1/(1 + exp(20 - 35 * x))
  g <- pmin(pmax(0, -0.8 + 6 * x - 5 * x^2), 1)
  b <- dnorm(x, 0.25, 0.15)/max(dnorm(x, 0.25, 0.15))
  rgb.m <- matrix(c(r, g, b), ncol = 3)
  rich.vector <- apply(rgb.m, 1, function(v) rgb(v[1],v[2],v[3],alpha = alpha))
}

plotBars.fn <- function(x,y,gap=0,add=F,ciCol="black",ciLty=1,ciLwd=1,...) {
  ## x is the x axis values (i.e., years)
  ## y is a data frame with:
  ## value: estimate (point) to plot
  ## lo: lower CI
  ## hi: higher CI

  if(!add) plot(x,y$value,...)
  if(add) points(x,y$value,...)
  segments(x,y$lo,x,y$value-gap,col=ciCol,lty=ciLty,lwd=ciLwd)
  segments(x,y$hi,x,y$value+gap,col=ciCol,lty=ciLty,lwd=ciLwd)
}

plotBars.fn <- function(x,y,gap=0,scalar=1e6,add=F,ciCol="black",ciLty=1,ciLwd=1,...) {
  ## x is the x axis values (i.e., years)
  ## y is a data frame with:
  ## value: estimate (point) to plot
  ## lo: lower CI
  ## hi: higher CI

  if(!add) plot(x,y$value/scalar,...)
  if(add) points(x,y$value/scalar,...)
  segments(x,y$lo/scalar,x,y$value/scalar-gap,col=ciCol,lty=ciLty,lwd=ciLwd)
  segments(x,y$hi/scalar,x,y$value/scalar+gap,col=ciCol,lty=ciLty,lwd=ciLwd) 
}

panel.letter <- function(letter){
  # adds letters to plot panels
  # letter is the letter to place on the panel
  usr <- par("usr")
  inset.x <- 0.05*(usr[2]-usr[1])
  inset.y <- 0.05*(usr[4]-usr[3])
  text(usr[1]+inset.x,usr[4]-inset.y,paste("(",letter,")",sep=""),cex=1.,font=1)
}

addpoly <- function(yrvec, lower, upper, color = 1, shade.col = NULL){
  lower[lower<0] <- 0 ## max of value or 0
  if(is.null(shade.col)){
    shade.col <- rgb(t(col2rgb(color)), alpha = 0.2 * 255, maxColorValue = 255)
  }
  polygon(x = c(yrvec, rev(yrvec)),
          y = c(lower, rev(upper)),
          border = NA,
          col = shade.col)
  lines(yrvec, lower, lty = 3, col = color)
  lines(yrvec, upper, lty = 3, col = color)
}

curfnfinder <- function(skipframes=0, skipnames="(FUN)|(.+apply)|(replicate)",
    retIfNone="Not in function", retStack=FALSE, extraPrefPerLevel="\t")
{
  # Get the current function name from within the function itself.
  # Used to prepend the function name to all messages so that the
  # user knows where the message came from.
    prefix<-sapply(3 + skipframes+1:sys.nframe(), function(i){
            currv<-sys.call(sys.parent(n=i))[[1]]
            return(currv)
        })
    prefix[grep(skipnames, prefix)] <- NULL
    prefix<-gsub("function \\(.*", "do.call", prefix)
    if(length(prefix)==0)
    {
        return(retIfNone)
    }
    else if(retStack)
    {
        return(paste(rev(prefix), collapse = "|"))
    }
    else
    {
        retval<-as.character(unlist(prefix[1]))
        if(length(prefix) > 1)
        {
            retval<-paste(paste(rep(extraPrefPerLevel, length(prefix) - 1), collapse=""), retval, sep="")
        }
        return(retval)
    }
}

catw <- function(..., file = "", sep = " ", fill = FALSE, labels = NULL,
    append = FALSE, prefix=0)
{
  # writes out some innformation on the calling function to screen
    if(is.numeric(prefix))
    {
        prefix<-curfnfinder(skipframes=prefix+1) #note: the +1 is there to avoid returning catw itself
        prefix<-paste(prefix, ": ", sep="")
    }
    cat(prefix, ..., format(Sys.time(), "(%Y-%m-%d %H:%M:%S)"), "\n",
        file = file, sep = sep, fill = fill, labels = labels, append = append)
}
