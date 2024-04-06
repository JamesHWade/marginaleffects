.PHONY: help testall testone document check install deploy deploydev html pdf news clean website

BOOK_DIR := book

help:  ## Display this help screen
	@echo -e "\033[1mAvailable commands:\033[0m\n"
	@grep -E '^[a-z.A-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' | sort

testall: ## tinytest::build_install_test()
	# Rscript -e "pkgload::load_all();cl <- parallel::makeCluster(5);tinytest::run_test_dir(cluster = cl)"
	Rscript -e "pkgload::load_all();tinytest::run_test_dir()"

testone: install ## make testone testfile="inst/tinytest/test-aaa-warn_once.R"
	Rscript -e "pkgload::load_all();tinytest::run_test_file('$(testfile)')"

document: ## altdoc::render_docs()
	Rscript -e "devtools::document()"

check: document ## devtools::check()
	Rscript -e "devtools::check()"

install: document ## devtools::install()
	Rscript -e "devtools::install()"

news: ## Download the latest changelog
	Rscript -e "source('book/utils/utils.R');get_news()"

pdf: news ## Render the book to PDF
	Rscript -e "source('book/utils/utils.R');get_quarto_yaml(pdf = TRUE)"
	cd $(BOOK_DIR) && quarto render --to pdf && cd ..
	rm -rf $(BOOK_DIR)/NEWS.qmd $(BOOK_DIR)/_quarto.qmd 
	make clean

html: news ## Render the book to HTML
	Rscript -e "source('book/utils/utils.R');get_quarto_yaml(pdf = FALSE, dev = FALSE)"
	cd $(BOOK_DIR) && quarto render --to html && cd ..
	rm -rf $(BOOK_DIR)/NEWS.qmd $(BOOK_DIR)/_quarto.qmd 
	make clean

htmldev: news ## Render the book to HTML
	Rscript -e "source('book/utils/utils.R');get_quarto_yaml(pdf = FALSE, dev = TRUE)"
	cd $(BOOK_DIR) && quarto render --to html && cd ..
	rm -rf $(BOOK_DIR)/NEWS.qmd $(BOOK_DIR)/_quarto.qmd 
	make clean

clean: ## Clean the book directory
	rm -rf $(BOOK_DIR)/NEWS.qmd $(BOOK_DIR)/_quarto.qmd 
	rm -rf ut 

setvar: ## Set the environment variable
	export R_BUILD_DOC=true

website: setvar ## altdoc::render_docs(verbose = TRUE)
	Rscript -e "reticulate::use_virtualenv(here::here('.venv'));altdoc::render_docs(verbose = TRUE, freeze = TRUE)"
