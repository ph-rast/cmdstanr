context("utils")

set_cmdstan_path()
fit_mcmc <- testing_fit("logistic", method = "sample",
                        seed = 123, chains = 2)
fit_mle <- testing_fit("logistic", method = "opt", seed = 123)


test_that("check_divergences() works", {
  csv_files <- c(test_path("resources", "csv", "model1-2-no-warmup.csv"))
  csv_output <- read_cmdstan_csv(csv_files)
  output <- "14 of 100 \\(14.0%\\) transitions ended with a divergence."
  expect_message(check_divergences(csv_output$post_warmup_sampler_diagnostics), output)

  csv_files <- c(test_path("resources", "csv", "model1-2-no-warmup.csv"),
                 test_path("resources", "csv", "model1-2-no-warmup.csv"))
  csv_output <- read_cmdstan_csv(csv_files)
  output <- "28 of 200 \\(14.0%\\) transitions ended with a divergence."
  expect_message(check_divergences(csv_output$post_warmup_sampler_diagnostics), output)

  csv_files <- c(test_path("resources", "csv", "model1-2-warmup.csv"))
  csv_output <- read_cmdstan_csv(csv_files)
  output <- "1 of 100 \\(1.0%\\) transitions ended with a divergence."
  expect_message(check_divergences(csv_output$post_warmup_sampler_diagnostics), output)


  fit_wramup_no_samples <- testing_fit("logistic", method = "sample",
                          seed = 123, chains = 1,
                          iter_sampling = 0,
                          iter_warmup = 10,
                          save_warmup = TRUE,
                          validate_csv = FALSE)
  csv_output <- read_cmdstan_csv(fit_wramup_no_samples$output_files())
  expect_message(check_divergences(csv_output$post_warmup_sampler_diagnostics), regexp = NA)
})

test_that("check_sampler_transitions_treedepth() works", {
  csv_files <- c(test_path("resources", "csv", "model1-2-no-warmup.csv"))
  csv_output <- read_cmdstan_csv(csv_files)
  output <- "16 of 100 \\(16.0%\\) transitions hit the maximum treedepth limit of 5 or 2\\^5-1 leapfrog steps."
  expect_message(
    check_sampler_transitions_treedepth(
      csv_output$post_warmup_sampler_diagnostics,
      csv_output$metadata),
    output
  )

  csv_files <- c(test_path("resources", "csv", "model1-2-no-warmup.csv"),
                 test_path("resources", "csv", "model1-2-no-warmup.csv"))
  csv_output <- read_cmdstan_csv(csv_files)
  output <- "32 of 200 \\(16.0%\\) transitions hit the maximum treedepth limit of 5 or 2\\^5-1 leapfrog steps."
  expect_message(
    check_sampler_transitions_treedepth(
      csv_output$post_warmup_sampler_diagnostics,
      csv_output$metadata),
    output
  )

  csv_files <- c(test_path("resources", "csv", "model1-2-warmup.csv"))
  csv_output <- read_cmdstan_csv(csv_files)
  output <- "1 of 100 \\(1.0%\\) transitions hit the maximum treedepth limit of 5 or 2\\^5-1 leapfrog steps."
  expect_message(
    check_sampler_transitions_treedepth(
      csv_output$post_warmup_sampler_diagnostics,
      csv_output$metadata),
    output
  )
})

test_that("cmdstan_summary works if bin/stansummary deleted file", {
  delete_and_run <- function() {
    file.remove(file.path(cmdstan_path(), "bin", cmdstan_ext("stansummary")))
    fit_mcmc$cmdstan_summary()
  }
  expect_output(delete_and_run(), "Inference for Stan model: logistic_model")
})

test_that("cmdstan_diagnose works if bin/diagnose deleted file", {
  delete_and_run <- function() {
    file.remove(file.path(cmdstan_path(), "bin", cmdstan_ext("diagnose")))
    fit_mcmc$cmdstan_diagnose()
  }
  expect_output(delete_and_run(), "Checking sampler transitions treedepth")
})

test_that("repair_path() fixes slashes", {
  # all slashes should be single "/", and no trailing slash
  expect_equal(repair_path("a//b\\c/"), "a/b/c")
})

test_that("repair_path works with zero length path or non-string path", {
  expect_equal(repair_path(""), "")
  expect_equal(repair_path(5), 5)
})

test_that("list_to_array works with empty list", {
  expect_equal(list_to_array(list()), NULL)
})

test_that("list_to_array fails for non-numeric values", {
  expect_error(list_to_array(list(k = "test"), name = "test-list"),
               "All elements in list 'test-list' must be numeric!")
})

test_that("cmdstan_make_local() works", {
  exisiting_make_local <- cmdstan_make_local()
  make_local_path <- file.path(cmdstan_path(), "make", "local")
  if (file.exists(make_local_path)) {
    file.remove(make_local_path)
  }
  expect_equal(cmdstan_make_local(), NULL)
  cpp_options = list(
   "CXX" = "clang++",
   "CXXFLAGS+= -march=native",
   TEST1 = TRUE,
   "TEST2" = FALSE
  )
  expect_equal(cmdstan_make_local(cpp_options = cpp_options),
               c(
                 "CXX=clang++",
                 "CXXFLAGS+= -march=native",
                 "TEST1=true",
                 "TEST2=false"
                 ))
  expect_equal(cmdstan_make_local(cpp_options = list("TEST3" = TRUE)),
               c(
                 "CXX=clang++",
                 "CXXFLAGS+= -march=native",
                 "TEST1=true",
                 "TEST2=false",
                 "TEST3=true"
               ))
  expect_equal(cmdstan_make_local(cpp_options = list("TEST4" = TRUE), append = FALSE),
               c("TEST4=true"))
  cmdstan_make_local(cpp_options = as.list(exisiting_make_local), append = FALSE)
})

test_that("matching_variables() works", {
  ret <- matching_variables(c("beta"),  c("alpha", "beta[1]", "beta[2]", "beta[3]"))
  expect_equal(
    ret$matching,
    c("beta[1]", "beta[2]", "beta[3]")
  )
  expect_equal(length(ret$not_found), 0)

  ret <- matching_variables(c("alpha"),  c("alpha", "beta[1]", "beta[2]", "beta[3]"))
  expect_equal(
    ret$matching,
    c("alpha")
  )
  expect_equal(length(ret$not_found), 0)

  ret <- matching_variables(c("alpha", "theta"),  c("alpha", "beta[1]", "beta[2]", "beta[3]"))
  expect_equal(
    ret$matching,
    c("alpha")
  )
  expect_equal(
    ret$not_found,
    c("theta")
  )

  ret <- matching_variables(c("alpha", "beta"),  c("alpha", "beta[1]", "beta[2]", "beta[3]"))
  expect_equal(
    ret$matching,
    c("alpha", "beta[1]", "beta[2]", "beta[3]")
  )
  expect_equal(length(ret$not_found), 0)
})

test_that("require_suggested_package() works", {
  expect_error(
    require_suggested_package("not_a_real_package"),
    "Please install the 'not_a_real_package' package to use this function."
  )
})

test_that("as_mcmc.list() works", {
  x <- as_mcmc.list(fit_mcmc)
  expect_length(x, fit_mcmc$num_chains())
  expect_s3_class(x, "mcmc.list")
  expect_s3_class(x[[1]], "mcmc")

  draws <- fit_mcmc$draws()
  x1 <- x[[1]]
  expect_equal(dim(x1), c(posterior::niterations(draws), posterior::nvariables(draws)))
  expect_equal(dimnames(x1)$variable, posterior::variables(draws))

  expect_error(
    as_mcmc.list(fit_mle),
    "Currently only CmdStanMCMC objects can be converted to mcmc.list"
  )
})
