source("helpers.R")
if (!EXPENSIVE) exit_file("EXPENSIVE")

set.seed(1024)
R <- 100
mod <- lm(Petal.Length ~ Sepal.Length * Sepal.Width, data = iris)

# simulation-based inference
x <- mod |> avg_predictions() |> inferences(method = "simulation", R = R)
expect_inherits(x, "predictions")
x <- mod |> slopes() |> inferences(method = "simulation", R = R) |> head()
expect_inherits(x, "slopes")
x <- mod |> predictions(vcov = "HC3") |> inferences(method = "simulation", R = R) |> head()
expect_inherits(x, "predictions")
x <- mod |> comparisons() |> inferences(method = "simulation", R = R) |> attr("posterior_draws")
expect_inherits(x, "matrix")


set.seed(1234)
# {boot}
x <- mod |> avg_predictions() |> inferences(method = "boot", R = R)
expect_inherits(x, "predictions")
expect_equivalent(nrow(x), 1)
expect_equal(x$std.error, 0.0491, tolerance = 1e-3)


# head works
set.seed(1234)
x <- mod |> slopes() |> inferences(method = "boot", R = R)
expect_inherits(head(x), "slopes")
expect_equivalent(nrow(x), 300)
expect_equivalent(nrow(head(x)), 6)
expect_equal(x$std.error[1:3], c(0.2425, 0.2824, 0.2626), tolerance = 1e-3)

# avg_ works
set.seed(1234)
x <- mod |> avg_slopes() |> inferences(method = "boot", R = R)
expect_inherits(x, "slopes")
expect_equivalent(nrow(x), 2)
expect_equal(x$std.error, c(0.0657, 0.1536), tolerance = 1e-3)


x <- mod |> predictions(vcov = "HC3") |> inferences(method = "boot", R = R) |> head()
expect_inherits(x, "predictions")
x <- mod |> comparisons() |> inferences(method = "boot", R = R) |> attr("inferences")
expect_inherits(x, "boot")
x <- mod |>
     comparisons(variables = "Sepal.Width", newdata = datagrid(Sepal.Length = range)) |> 
     inferences(method = "boot", R = R)
expect_equivalent(nrow(x), 2)
x <- mod|> avg_comparisons() |> inferences(method = "simulation", R = R)
expect_equivalent(nrow(x), 2)
x <- x |> posterior_draws()
expect_equivalent(nrow(x), 2 * R)


# {rsample}
set.seed(1234)
x <- mod |> avg_predictions() |> inferences(method = "rsample", R = R)
expect_equal(x$conf.low, 3.6692, tolerance = 1e-3)
expect_inherits(x, "predictions")
x <- mod |> slopes() |> inferences(method = "rsample", R = R) |> head()
expect_inherits(x, "slopes")
x <- mod |> predictions(vcov = "HC3") |> inferences(method = "rsample", R = R) |> head()
expect_inherits(x, "predictions")
x <- mod |> comparisons() |> inferences(method = "rsample", R = R) |> attr("inferences")
expect_inherits(x, "bootstraps")
x <- mod |>
     comparisons(variables = "Sepal.Width", newdata = datagrid(Sepal.Length = range)) |>
     inferences(method = "rsample", R = R)
expect_equivalent(nrow(x), 2)
x <- mod |>
     avg_comparisons() |>
     inferences(method = "rsample", R = R) |>
     posterior_draws()
expect_equivalent(nrow(x), 2 * R)

# fwb no validity check
set.seed(1234)
x <- mod |> 
     comparisons() |> 
     inferences(method = "fwb", R = R)
expect_equivalent(nrow(x), 300)
expect_equal(x$std.error[1:3], c(0.0739, 0.0568, 0.0508), tolerance = 1e-3)
x <- mod |> 
     avg_comparisons() |> 
     inferences(method = "fwb", R = R)
expect_equivalent(nrow(x), 2)


# {fwb} error when user supplied its own weightso
dat <- transform(mtcars, w = runif(32))
mod <- lm(mpg ~ hp, data = dat)
expect_error(inferences(comparisons(mod, wts = "w"), method = "fwb"), pattern = "wts")


# Issue #856
tmp <- lm(Petal.Length ~ Sepal.Length * Species, data = iris)
cmp <- avg_comparisons(tmp,
    variables = list(Sepal.Length = 1, Species = "reference"),
    cross = TRUE) |>
    inferences(method = "boot", R = 5) |>
    suppressWarnings()
expect_inherits(cmp, "comparisons")
expect_equal(nrow(cmp), 2)


# Issue #853
m <- glm(am ~ mpg + hp + cyl, data = mtcars, family = binomial)
p <- avg_predictions(m, by = "cyl") |>
  inferences(method = "boot", R = 5) |>
  suppressWarnings()
expect_inherits(p, "predictions")
p <- predictions(m, by = "cyl") |>
  inferences(method = "boot", R = 5) |>
  suppressWarnings()
expect_inherits(p, "predictions")


# Issue #851: simulation-based inference use the original estimates, not the mean/median of simulations
mod <- glm(vs ~ hp + mpg + am, data = mtcars, family = binomial)
cmp1 <- avg_comparisons(mod)
cmp2 <- cmp1 |> inferences(method = "simulation", R = 500)
expect_equivalent(cmp1$estimate, cmp2$estimate)


# mfxplainer bug
mod <- lm(mpg ~ hp + cyl, data = mtcars)
p <- avg_predictions(mod, by = "cyl") |> inferences(method = "simulation", R = 25)
expect_inherits(p, "predictions")


# inferences with hypotheses
mod <- lm(mpg ~ hp + cyl, data = mtcars)
p <- hypotheses(mod, hypothesis = "hp/cyl=1") |> inferences(method = "boot", R = 25) |> suppressWarnings()
expect_inherits(p, "hypotheses")
p <- hypotheses(mod, hypothesis = "hp/cyl=1") |> inferences(method = "simulation", R = 25)
expect_inherits(p, "hypotheses")


# Issue #1054
requiet("lme4")
mod <- glmer(
  cbind(incidence, size - incidence) ~ period + (1 | herd),
  data = cbpp, family = binomial)
cmp <- avg_comparisons(mod, variables = "period") |>
    inferences(method="simulation", R = 15)
expect_inherits(cmp, "comparisons")



# Clarify comparison
requiet("clarify")
requiet("MatchIt")
data("lalonde", package = "MatchIt")
set.seed(1025)
fit <- glm(I(re78 == 0) ~ treat * (age + educ + race + married + nodegree + re74 + re75),
           data = lalonde, family = binomial)
sim_coefs <- clarify::sim(fit)
ATT_fun <- function(fit) {
  d <- subset(lalonde, treat == 1)
  d$treat <- 1
  p1 <- mean(predict(fit, newdata = d, type = "response"))
  d$treat <- 0
  p0 <- mean(predict(fit, newdata = d, type = "response"))
  c(`E[Y(0)]` = p0, `E[Y(1)]` = p1, `RR` = p1 / p0)
}
sim_est <- sim_apply(sim_coefs, ATT_fun, verbose = FALSE)
s1 <- summary(sim_est)
s3 <- avg_predictions(fit, variables = "treat", type = "response", newdata = subset(lalonde, treat == 1)) |>
    inferences(method = "simulation", R = 1000)
expect_equivalent(s1[1:2, 2], s3$conf.low, tolerance= .03)
expect_equivalent(s1[1:2, 3], s3$conf.high, tolerance= .03)


# issue #1124: inferences is on the correct scale
set.seed(1024)
dat <- read.csv("https://marginaleffects.com/data/impartiality.csv")
m <- glm(
  impartial ~ equal * democracy + continent, 
  data = dat, family = binomial)
p <- predictions(m, by = "democracy", type = "response") |> 
     inferences(method = "simulation", R = 100)
expect_true(all(p$estimate > 0 & p$estimate < 1))
expect_true(all(p$conf.low > 0 & p$conf.low < 1))
expect_true(all(p$conf.high > 0 & p$conf.high < 1))
expect_true(all(p$conf.low < p$estimate & p$conf.high > p$estimate))

p2 <- predictions(m, by = "democracy", type = "response")
expect_equivalent(p2$estimate, p$estimate)



rm(list = ls())
